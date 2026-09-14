# app/scripts/07_experimentos.R
# Roda as 4 analises obrigatorias (Projeto_TRA48.pdf, secao 4.4):
#   1. Relaxacao linear vs. solucao original
#   2. Interpretacao economica do dual
#   3. Analise de sensibilidade nos parametros assumidos
#   4. Curva de implantacao (beneficio vs. numero de vertiportos)
# Le os dados processados (app/data/processed/), resolve o modelo
# (app/scripts/06_modelo_hub.R) varias vezes, e escreve tabelas de
# resultado em app/results/tabelas/ e uma figura em app/results/figuras/.

suppressMessages(library(lpSolve))
here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))
source(here("scripts", "04_parametros.R"))
source(here("scripts", "06_modelo_hub.R"))

proc <- here("data", "processed")
res_tab <- here("results", "tabelas")
res_fig <- here("results", "figuras")
dir.create(res_tab, showWarnings = FALSE, recursive = TRUE)
dir.create(res_fig, showWarnings = FALSE, recursive = TRUE)

regioes <- read.csv(file.path(proc, "macrorregioes_centroides.csv"))
W <- as.matrix(read.csv(file.path(proc, "demanda_capturavel.csv"), row.names = 1))
colnames(W) <- rownames(W) <- regioes$nome
tempos <- construir_tempos(regioes, PARAMS)

P_REF <- 4  # p de referencia para relaxacao/dual (justificativa: ponto medio
            # da curva de implantacao, ver secao 4 abaixo; usado so como caso
            # didatico para a leitura do dual, nao e' a recomendacao final)

log_lines <- character(0)
logf <- function(...) {
  s <- paste0(...)
  cat(s, "\n")
  log_lines <<- c(log_lines, s)
}

## ============================================================
## 1. Relaxacao linear vs. solucao original (p = P_REF)
## ============================================================
logf("\n===== 1. RELAXACAO LINEAR (p=", P_REF, ") =====")
m_milp <- construir_e_resolver(W, tempos, p = P_REF, relax = FALSE, compute_sens = TRUE)
m_lp   <- construir_e_resolver(W, tempos, p = P_REF, relax = TRUE,  compute_sens = TRUE)

sol_milp <- extrair_solucao(m_milp, regioes)
h_lp <- m_lp$sol$solution[m_lp$idx_h(seq_len(m_lp$N))]

tab_relax <- data.frame(
  modelo = c("MILP (h binario)", "Relaxacao linear (h continuo)"),
  objetivo_h_passageiro_dia = c(m_milp$sol$objval, m_lp$sol$objval),
  gap_pct = c(0, 100 * (m_milp$sol$objval - m_lp$sol$objval) / m_milp$sol$objval)
)
logf("Objetivo MILP: ", round(m_milp$sol$objval, 1), " horas-passageiro/dia")
logf("Objetivo LP relaxado: ", round(m_lp$sol$objval, 1), " horas-passageiro/dia")
logf("Gap de integralidade: ", round(tab_relax$gap_pct[2], 3), "%")
logf("h_k na relaxacao (fracao aberta por candidato):")
for (k in seq_len(m_lp$N)) logf("  ", regioes$nome[k], ": ", round(h_lp[k], 4))
n_fracionarios <- sum(h_lp > 1e-6 & h_lp < 1 - 1e-6)
logf("Numero de h_k fracionarios na relaxacao: ", n_fracionarios)
write.csv(tab_relax, file.path(res_tab, "01_relaxacao.csv"), row.names = FALSE)
write.csv(data.frame(candidato = regioes$nome, h_milp = m_milp$sol$solution[m_milp$idx_h(1:m_milp$N)],
                      h_relaxado = h_lp),
          file.path(res_tab, "01_relaxacao_h.csv"), row.names = FALSE)

# Checa o gap em TODOS os p viaveis (2..N), nao so' no p de referencia, para
# nao generalizar uma conclusao a partir de um unico ponto.
gap_todos_p <- do.call(rbind, lapply(2:nrow(regioes), function(p) {
  mi <- construir_e_resolver(W, tempos, p = p, relax = FALSE, compute_sens = FALSE)
  ml <- construir_e_resolver(W, tempos, p = p, relax = TRUE, compute_sens = FALSE)
  h <- ml$sol$solution[ml$idx_h(seq_len(ml$N))]
  data.frame(p = p, milp = mi$sol$objval, lp = ml$sol$objval,
             gap_pct = 100 * (mi$sol$objval - ml$sol$objval) / mi$sol$objval,
             n_h_fracionario = sum(h > 1e-6 & h < 1 - 1e-6))
}))
logf("\nGap MILP vs. LP relaxado para todo p viavel (2..", nrow(regioes), "):")
print(gap_todos_p)
write.csv(gap_todos_p, file.path(res_tab, "01_relaxacao_todos_p.csv"), row.names = FALSE)
if (all(gap_todos_p$gap_pct < 1e-6)) {
  logf("\nO gap e' 0% (h_k ja' sai inteiro na relaxacao) em TODOS os p testados,",
       " nao so' no p de referencia. Isso e' consistente com a formulacao de",
       " hub location de alocacao multipla sem restricao de capacidade: a",
       " submatriz das variaveis de fluxo x_ijkl tem estrutura proxima de um",
       " problema de fluxo em rede/transporte para h_k fixo, e o unico",
       " acoplamento inteiro esta' na cardinalidade (4) e nas ligacoes (2)-(3)",
       " -- o que, empiricamente nesta instancia pequena (8 regioes, sem",
       " capacidade), basta para que os vertices otimos da relaxacao ja'",
       " caiam em pontos inteiros. Isso NAO e' garantido em geral: assim que",
       " se adiciona uma restricao de capacidade por vertiporto (trabalho",
       " futuro, ver formulacao.md secao 7), essa integralidade tende a se",
       " perder e o gap deve aparecer.")
}

## ============================================================
## 2. Interpretacao economica do dual (na relaxacao linear, p = P_REF)
## ============================================================
logf("\n===== 2. DUAL (relaxacao linear, p=", P_REF, ") =====")
duals <- m_lp$sol$duals  # ordem: restricoes (1)..(4), depois reduced costs das variaveis
n_c1 <- m_lp$n_od
n_c2 <- m_lp$n_od * m_lp$N
n_c3 <- m_lp$n_od * m_lp$N
duals_c2 <- duals[(n_c1 + 1):(n_c1 + n_c2)]
duals_c3 <- duals[(n_c1 + n_c2 + 1):(n_c1 + n_c2 + n_c3)]
dual_c4 <- duals[n_c1 + n_c2 + n_c3 + 1]

# soma (em valor absoluto) do dual das restricoes (2)/(3) por candidato k:
# interpreta-se como o quanto o tempo total serviria de menos (em horas-
# passageiro/dia) se o candidato k "valesse" uma unidade a mais de folga na
# restricao de alocacao -- ou seja, o quao apertado/escasso aquele vertiporto
# candidato e' como recurso de alocacao.
# indexacao: bloco (2) e' ordenado por od-externo, k-interno (ver
# 06_modelo_hub.R: "for r in od { for k in 1:N { ... } }")
preco_sombra_k2 <- sapply(seq_len(m_lp$N), function(k) {
  idx <- seq(k, n_c2, by = m_lp$N)
  sum(duals_c2[idx])
})
preco_sombra_l2 <- sapply(seq_len(m_lp$N), function(l) {
  idx <- seq(l, n_c3, by = m_lp$N)
  sum(duals_c3[idx])
})

tab_dual <- data.frame(
  candidato = regioes$nome,
  h_aberto_relax = round(h_lp, 3),
  preco_sombra_embarque = round(preco_sombra_k2, 4),
  preco_sombra_desembarque = round(preco_sombra_l2, 4)
)
logf("Preco-sombra (dual) agregado por candidato — horas-passageiro/dia",
     " economizadas por unidade de folga na capacidade de alocacao do vertiporto:")
print(tab_dual)
logf("Dual da restricao (4) [numero de vertiportos = p]: ", round(dual_c4, 4),
     " horas-passageiro/dia por vertiporto adicional (custo marginal de reduzir p em 1")
write.csv(tab_dual, file.path(res_tab, "02_dual.csv"), row.names = FALSE)

logf("\nLeitura economica: candidatos com preco-sombra mais negativo (em modulo,",
     " mais distante de zero) sao os vertiportos cuja folga de alocacao mais",
     " reduziria o tempo total se pudesse ser relaxada -- ou seja, sao os",
     " 'recursos' mais escassos da rede na configuracao com p=", P_REF, ".",
     " O dual de (4) mostra quanto tempo total (h-passageiro/dia) se ganharia",
     " abrindo mais um vertiporto -- e' o numero que sustenta, junto com a",
     " curva de implantacao (secao 4), a decisao de ate quando vale a pena",
     " aumentar p.")

## ============================================================
## 3. Analise de sensibilidade
## ============================================================
logf("\n===== 3. SENSIBILIDADE (p=", P_REF, ") =====")

resolver_com_params <- function(theta = PARAMS$THETA, v_acesso = PARAMS$V_ACESSO_KMH,
                                 d_min = PARAMS$D_MIN_KM, pct_renda = PARAMS$PERCENTIL_RENDA_MIN,
                                 p = P_REF) {
  pr <- PARAMS
  pr$THETA <- theta; pr$V_ACESSO_KMH <- v_acesso; pr$D_MIN_KM <- d_min
  pr$PERCENTIL_RENDA_MIN <- pct_renda

  Wb <- as.matrix(read.csv(file.path(proc, "demanda_macrorregioes_bruta.csv"), row.names = 1))
  N <- nrow(Wb)
  Dkm <- matrix(0, N, N)
  for (a in 1:N) for (b in 1:N) Dkm[a, b] <- dist_utm_km(regioes$utm_x[a], regioes$utm_y[a],
                                                            regioes$utm_x[b], regioes$utm_y[b])
  corte <- quantile(regioes$renda_media_familiar, pct_renda)
  eleg_renda <- regioes$renda_media_familiar >= corte
  Wc <- matrix(0, N, N)
  for (a in 1:N) for (b in 1:N) {
    if (a == b) next
    if (Dkm[a, b] < d_min) next
    if (!eleg_renda[a]) next
    Wc[a, b] <- Wb[a, b] * theta
  }
  temp <- construir_tempos(regioes, pr)
  m <- construir_e_resolver(Wc, temp, p = p, relax = FALSE, compute_sens = FALSE)
  s <- extrair_solucao(m, regioes)
  data.frame(theta = theta, v_acesso_kmh = v_acesso, d_min_km = d_min,
             percentil_renda = pct_renda, p = p, status = s$status,
             demanda_total_dia = round(s$demanda_total_dia),
             objetivo_h_dia = round(s$objval_h_dia, 1),
             economia_total_h_dia = round(s$economia_total_h_dia, 1),
             n_hubs_abertos = length(s$hubs_abertos_nome),
             hubs = paste(s$hubs_abertos_nome, collapse = "; "))
}

cenarios <- rbind(
  resolver_com_params(),  # base
  resolver_com_params(theta = 0.02),
  resolver_com_params(theta = 0.10),
  resolver_com_params(theta = 0.15),
  resolver_com_params(v_acesso = 15),
  resolver_com_params(v_acesso = 25),
  resolver_com_params(v_acesso = 30),
  resolver_com_params(d_min = 5),
  resolver_com_params(d_min = 12),
  resolver_com_params(pct_renda = 0.50),
  resolver_com_params(pct_renda = 0.80)
)
cenarios$cenario <- c("base", "theta=2%", "theta=10%", "theta=15%",
                       "v_acesso=15", "v_acesso=25", "v_acesso=30",
                       "d_min=5km", "d_min=12km", "renda_pctl=50%", "renda_pctl=80%")
cenarios <- cenarios[, c("cenario", setdiff(names(cenarios), "cenario"))]
print(cenarios[, c("cenario", "demanda_total_dia", "objetivo_h_dia", "economia_total_h_dia", "n_hubs_abertos")])
write.csv(cenarios, file.path(res_tab, "03_sensibilidade.csv"), row.names = FALSE)

logf("\nLeitura: a demanda capturavel total (e portanto o beneficio absoluto)",
     " e' extremamente sensivel a theta (escala linear) e ao corte de renda",
     " (que muda QUAIS zonas de origem entram no modelo, nao so a escala).",
     " O conjunto de hubs abertos e' mais estavel a variacoes de v_acesso do",
     " que a mudancas no corte de renda -- ou seja, a decisao de ONDE",
     " localizar e' mais robusta a incerteza de velocidade de acesso do que",
     " a hipotese de quem e' o publico-alvo da demanda.")

## ============================================================
## 4. Curva de implantacao (benef. vs. numero de vertiportos, p=1..N)
## ============================================================
logf("\n===== 4. CURVA DE IMPLANTACAO =====")
N <- nrow(regioes)
curva <- do.call(rbind, lapply(1:N, function(p) {
  m <- construir_e_resolver(W, tempos, p = p, relax = FALSE, compute_sens = FALSE)
  s <- extrair_solucao(m, regioes)
  data.frame(p = p, status = s$status, objetivo_h_dia = s$objval_h_dia,
             economia_total_h_dia = s$economia_total_h_dia,
             hubs = paste(s$hubs_abertos_nome, collapse = "; "))
}))
logf("Nota: p=1 e' inviavel por construcao neste modelo — um par de hub",
     " (k != l) exige pelo menos 2 vertiportos abertos, entao com p=1 nenhum",
     " voo e' possivel e a restricao (1) (toda a demanda tem que ser roteada)",
     " nao tem solucao viavel. Isto E' um resultado, nao um bug: mostra que",
     " uma rede de 1 vertiporto so' nao sustenta nenhuma rota de UAM neste",
     " desenho hub-and-spoke.")
curva$economia_marginal_h_dia <- c(NA, diff(curva$economia_total_h_dia))
print(curva[, c("p", "economia_total_h_dia", "economia_marginal_h_dia", "hubs")])
write.csv(curva, file.path(res_tab, "04_curva_implantacao.csv"), row.names = FALSE)

png(file.path(res_fig, "curva_implantacao.png"), width = 900, height = 600, res = 120)
par(mar = c(4.5, 4.5, 2, 4.5))
plot(curva$p, curva$economia_total_h_dia, type = "b", pch = 19, col = "#0b5fa5",
     xlab = "Numero de vertiportos implantados (p)",
     ylab = "Economia total de tempo (horas-passageiro/dia)",
     main = "Curva de implantacao — beneficio vs. numero de vertiportos")
par(new = TRUE)
plot(curva$p, curva$economia_marginal_h_dia, type = "b", pch = 17, lty = 2, col = "#c0392b",
     axes = FALSE, xlab = "", ylab = "")
axis(4, col = "#c0392b", col.axis = "#c0392b")
mtext("Economia marginal (h-passag./dia por vertiporto adicional)", side = 4, line = 3, col = "#c0392b")
legend("bottomright", legend = c("Economia total", "Economia marginal"),
       col = c("#0b5fa5", "#c0392b"), pch = c(19, 17), lty = c(1, 2), bty = "n", cex = 0.8)
dev.off()
logf("Figura salva em ", file.path(res_fig, "curva_implantacao.png"))

logf("\nLeitura da curva: a economia marginal por vertiporto adicional cai",
     " a medida que p cresce (retornos decrescentes esperados em hub location:",
     " os primeiros vertiportos capturam os pares OD de maior fluxo/maior",
     " distancia, os seguintes capturam pares cada vez menores). O ponto em",
     " que a economia marginal fica pequena frente ao total acumulado e' o",
     " candidato natural a 'a partir de quantos vertiportos o retorno deixa",
     " de compensar' (Projeto_TRA48.pdf, 4.4) -- ver tabela completa em",
     " app/results/tabelas/04_curva_implantacao.csv para a leitura numerica",
     " exata por grupo, dado que a resposta depende de quanto se valoriza",
     " tempo economizado marginal vs. custo de expansao (que nao monetizamos,",
     " ver formulacao.md secao 5).")

## ============================================================
## 5. Monetizacao ilustrativa (NAO e' analise de custo-beneficio rigorosa)
## ============================================================
logf("\n===== 5. Monetizacao ilustrativa do beneficio (p=", P_REF, ") =====")
# Valor do tempo (VOT) como fracao do salario-hora medio das zonas
# ELEGIVEIS por renda (Small, 2012; convencao usual ~30-50% do salario
# bruto por hora para viagens pessoais urbanas). Ilustrativo, nao e'
# avaliacao de projeto formal (nao inclui excedente do consumidor, custo
# de oportunidade do capital, etc.)
renda_media_eleg <- weighted.mean(
  regioes$renda_media_familiar[regioes$renda_media_familiar >= quantile(regioes$renda_media_familiar, PARAMS$PERCENTIL_RENDA_MIN)],
  regioes$populacao[regioes$renda_media_familiar >= quantile(regioes$renda_media_familiar, PARAMS$PERCENTIL_RENDA_MIN)]
)
salario_hora <- renda_media_eleg / (30 * 8)  # 30 dias x 8h/dia, aproximacao grosseira
VOT_RS_HORA <- 0.4 * salario_hora
economia_rs_dia_pref <- sol_milp$economia_total_h_dia * VOT_RS_HORA
logf("Renda familiar media (zonas elegiveis, ponderada por populacao): R$ ", round(renda_media_eleg))
logf("Valor do tempo assumido (40% do salario-hora implicito): R$ ", round(VOT_RS_HORA, 2), "/h")
logf("Economia monetizada (p=", P_REF, "): R$ ",
     formatC(round(economia_rs_dia_pref), format = "d", big.mark = "."), "/dia",
     " (ilustrativo — ver ressalva acima)")

writeLines(log_lines, file.path(res_tab, "log_experimentos.txt"))
cat("\n\nOK — tabelas em app/results/tabelas/, figura em app/results/figuras/\n")
