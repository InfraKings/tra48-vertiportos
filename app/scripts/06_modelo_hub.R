# app/scripts/06_modelo_hub.R
# Monta e resolve o modelo de hub location (p-hub median, alocacao
# multipla) descrito em app/formulacao.md. Fornece uma unica funcao,
# construir_e_resolver(), reusada por 07_experimentos.R para: solucao
# original (MILP), relaxacao linear, analise de dual, sensibilidade e
# curva de implantacao -- todas resolvem a mesma estrutura de modelo,
# variando p, parametros de demanda/tempo, ou o tipo (LP vs MILP).

suppressMessages(library(lpSolve))

here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))

#' Constroi as matrizes de tempo (acesso, voo, egresso, baseline) a partir
#' dos centroides das macrorregioes e dos parametros de velocidade.
construir_tempos <- function(regioes, params) {
  N <- nrow(regioes)
  Dkm <- matrix(0, N, N)
  for (a in 1:N) for (b in 1:N) {
    Dkm[a, b] <- dist_utm_km(regioes$utm_x[a], regioes$utm_y[a],
                              regioes$utm_x[b], regioes$utm_y[b])
  }
  t_acesso <- params$FATOR_SINUOSIDADE * Dkm / params$V_ACESSO_KMH          # h, [i,k]
  t_voo <- Dkm / params$V_CRUZEIRO_KMH + params$T_OVERHEAD_VOO_H           # h, [k,l]
  t0 <- params$FATOR_SINUOSIDADE * Dkm / params$V_ACESSO_KMH               # h, [i,j] (linha de base)
  list(Dkm = Dkm, t_acesso = t_acesso, t_voo = t_voo, t0 = t0)
}

#' Constroi e resolve o modelo para um dado p (numero de vertiportos) e uma
#' dada matriz de demanda capturavel W (N x N, W[i,j] = viagens/dia).
#' relax=TRUE resolve a relaxacao linear (h_k continuo em [0,1] em vez de
#' binario). compute.sens=TRUE pede a lpSolve os dados de sensibilidade/dual.
#' Retorna uma lista com o objeto lp() bruto e campos derivados uteis.
construir_e_resolver <- function(W, tempos, p, relax = FALSE, compute_sens = TRUE) {
  N <- nrow(W)
  pares_od <- which(W > 0, arr.ind = TRUE)  # cada linha: i, j
  n_od <- nrow(pares_od)
  if (n_od == 0) stop("Nenhum par OD com demanda capturavel > 0.")

  # pares de hub k != l
  hub_pairs <- expand.grid(k = 1:N, l = 1:N)
  hub_pairs <- hub_pairs[hub_pairs$k != hub_pairs$l, ]
  n_hp <- nrow(hub_pairs)

  # indice das variaveis x_ijkl: para cada par od (linha de pares_od), um
  # bloco de n_hp variaveis (uma por par de hub). Variaveis h_k vem depois.
  n_x <- n_od * n_hp
  n_h <- N
  n_vars <- n_x + n_h

  idx_x <- function(od_row, hp_row) (od_row - 1) * n_hp + hp_row
  idx_h <- function(k) n_x + k

  ## --- Coeficientes do objetivo -------------------------------------------
  obj <- numeric(n_vars)
  for (r in seq_len(n_od)) {
    i <- pares_od[r, 1]; j <- pares_od[r, 2]
    custo <- tempos$t_acesso[i, hub_pairs$k] + tempos$t_voo[cbind(hub_pairs$k, hub_pairs$l)] +
      tempos$t_acesso[hub_pairs$l, j]  # t_acesso reusado tambem como egresso (mesma formula/parametro)
    obj[idx_x(r, seq_len(n_hp))] <- W[i, j] * custo
  }
  # h_k nao entra no objetivo (sem custo fixo, ver formulacao.md secao 5)

  ## --- Restricoes -----------------------------------------------------------
  # (1) soma_kl x_ijkl = 1, para cada par od
  # (2) soma_l x_ijkl - h_k <= 0, para cada (od, k)
  # (3) soma_k x_ijkl - h_l <= 0, para cada (od, l)
  # (4) soma_k h_k = p
  n_c1 <- n_od
  n_c2 <- n_od * N
  n_c3 <- n_od * N
  n_c4 <- 1
  n_rows <- n_c1 + n_c2 + n_c3 + n_c4

  A <- matrix(0, n_rows, n_vars)
  rhs <- numeric(n_rows)
  dirs <- character(n_rows)
  row <- 0

  # (1)
  for (r in seq_len(n_od)) {
    row <- row + 1
    A[row, idx_x(r, seq_len(n_hp))] <- 1
    rhs[row] <- 1; dirs[row] <- "="
  }
  # (2): soma sobre l (para cada k fixo) das variaveis com hub_pairs$k==k
  for (r in seq_len(n_od)) {
    for (k in seq_len(N)) {
      row <- row + 1
      sel <- which(hub_pairs$k == k)
      A[row, idx_x(r, sel)] <- 1
      A[row, idx_h(k)] <- -1
      rhs[row] <- 0; dirs[row] <- "<="
    }
  }
  # (3): soma sobre k (para cada l fixo)
  for (r in seq_len(n_od)) {
    for (l in seq_len(N)) {
      row <- row + 1
      sel <- which(hub_pairs$l == l)
      A[row, idx_x(r, sel)] <- 1
      A[row, idx_h(l)] <- -1
      rhs[row] <- 0; dirs[row] <- "<="
    }
  }
  # (4)
  row <- row + 1
  A[row, idx_h(seq_len(N))] <- 1
  rhs[row] <- p; dirs[row] <- "="

  stopifnot(row == n_rows)

  bin_vec <- idx_h(seq_len(N))
  sol <- if (relax) {
    lp("min", obj, A, dirs, rhs, compute.sens = if (compute_sens) 1 else 0)
  } else {
    lp("min", obj, A, dirs, rhs, int.vec = bin_vec, binary.vec = bin_vec,
       compute.sens = if (compute_sens) 1 else 0)
  }

  list(sol = sol, obj = obj, A = A, dirs = dirs, rhs = rhs,
       pares_od = pares_od, hub_pairs = hub_pairs,
       n_od = n_od, n_hp = n_hp, n_x = n_x, n_h = n_h, N = N,
       idx_x = idx_x, idx_h = idx_h, W = W, tempos = tempos, p = p)
}

#' Extrai a solucao (quais hubs abertos, alocacao por par OD, tempo medio,
#' tempo economizado vs baseline) de um objeto retornado por
#' construir_e_resolver().
extrair_solucao <- function(m, regioes) {
  if (m$sol$status != 0) {
    # p inviavel (ex.: p=1 nesta formulacao — precisa de pelo menos 2
    # vertiportos abertos para existir algum par k != l). Nao inventa
    # numero: reporta status e deixa metricas como NA.
    return(list(
      status = m$sol$status, objval_h_dia = NA,
      hubs_abertos_idx = integer(0), hubs_abertos_nome = character(0),
      detalhe_od = NULL, demanda_total_dia = sum(m$W[m$pares_od]),
      economia_total_h_dia = NA, pares_com_economia_negativa = NA
    ))
  }
  x <- m$sol$solution
  h <- x[m$idx_h(seq_len(m$N))]
  hubs_abertos <- which(h > 0.5)

  linhas <- lapply(seq_len(m$n_od), function(r) {
    i <- m$pares_od[r, 1]; j <- m$pares_od[r, 2]
    xv <- x[m$idx_x(r, seq_len(m$n_hp))]
    tempo_uam <- sum(xv * (m$tempos$t_acesso[i, m$hub_pairs$k] +
                             m$tempos$t_voo[cbind(m$hub_pairs$k, m$hub_pairs$l)] +
                             m$tempos$t_acesso[m$hub_pairs$l, j]))
    kl_usado <- m$hub_pairs[xv > 1e-6, ]
    data.frame(
      origem = regioes$nome[i], destino = regioes$nome[j], W_ij = m$W[i, j],
      tempo_uam_h = tempo_uam, tempo_base_h = m$tempos$t0[i, j],
      economia_h_viagem = m$tempos$t0[i, j] - tempo_uam,
      economia_h_dia = m$W[i, j] * (m$tempos$t0[i, j] - tempo_uam),
      hub_embarque = paste(regioes$nome[kl_usado$k], collapse = "|"),
      hub_desembarque = paste(regioes$nome[kl_usado$l], collapse = "|")
    )
  })
  df <- do.call(rbind, linhas)

  list(
    status = m$sol$status, objval_h_dia = m$sol$objval,
    hubs_abertos_idx = hubs_abertos, hubs_abertos_nome = regioes$nome[hubs_abertos],
    detalhe_od = df,
    demanda_total_dia = sum(m$W[m$pares_od]),
    economia_total_h_dia = sum(df$economia_h_dia),
    pares_com_economia_negativa = sum(df$economia_h_viagem < 0)
  )
}
