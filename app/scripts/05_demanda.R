# app/scripts/05_demanda.R
# Le a Tabela 25 (matriz 517x517 de viagens diarias por transporte
# individual motorizado, OD2017), agrega para a matriz 8x8 de
# macrorregioes, e aplica a hipotese de demanda capturavel por UAM
# (elegibilidade por distancia + renda + fracao comportamental theta,
# parametros em 04_parametros.R). Saida:
#   app/data/processed/demanda_macrorregioes_bruta.csv  (viagens motorizadas
#     individuais agregadas por par de macrorregiao, sem filtro)
#   app/data/processed/demanda_capturavel.csv (W_ij usado no modelo)

suppressMessages(library(readxl))

here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))
source(here("scripts", "04_parametros.R"))

raw <- here("data", "raw")
proc <- here("data", "processed")

## 1. Le a matriz 517x517 bruta (individual motorizado) ---------------------
tab25 <- read_excel(file.path(raw, "Tab25_OD2017.xlsx"), sheet = 1, col_names = FALSE)
tab25 <- as.data.frame(tab25)
col1 <- suppressWarnings(as.numeric(tab25[[1]]))
r0 <- which(!is.na(col1) & col1 == 1)[1]
mat_zonas <- as.matrix(tab25[r0:(r0 + 516), 2:518])
mat_zonas <- apply(mat_zonas, 2, as.numeric)  # 517 x 517, [origem, destino]
stopifnot(dim(mat_zonas) == c(517, 517))

## 2. Agrega para macrorregioes ----------------------------------------------
zr <- read.csv(file.path(proc, "macrorregioes_zonas.csv"))  # zona -> macrorregiao (ordem = zona 1..517)
zr <- zr[order(zr$zona), ]
stopifnot(nrow(zr) == 517, all(zr$zona == 1:517))
reg <- zr$macrorregiao
N <- max(reg)

W_bruta <- matrix(0, N, N)
for (a in seq_len(N)) {
  for (b in seq_len(N)) {
    W_bruta[a, b] <- sum(mat_zonas[reg == a, reg == b])
  }
}
regioes <- read.csv(file.path(proc, "macrorregioes_centroides.csv"))
rownames(W_bruta) <- colnames(W_bruta) <- regioes$nome

write.csv(W_bruta, file.path(proc, "demanda_macrorregioes_bruta.csv"))

cat("Total viagens individuais motorizadas (517 zonas):", sum(mat_zonas), "\n")
cat("Total apos agregacao 8x8 (deve bater):", sum(W_bruta), "\n")
cat("Total intra-regiao (diagonal, excluida do modelo):", sum(diag(W_bruta)), "\n")

## 3. Elegibilidade: distancia entre macrorregioes ---------------------------
D_km <- matrix(0, N, N)
for (a in seq_len(N)) for (b in seq_len(N)) {
  D_km[a, b] <- dist_utm_km(regioes$utm_x[a], regioes$utm_y[a], regioes$utm_x[b], regioes$utm_y[b])
}

## 4. Elegibilidade: renda da zona de origem (percentil) --------------------
corte_renda <- quantile(regioes$renda_media_familiar, PARAMS$PERCENTIL_RENDA_MIN)
elegivel_renda <- regioes$renda_media_familiar >= corte_renda

## 5. Monta W_ij capturavel ---------------------------------------------------
W_cap <- matrix(0, N, N)
for (a in seq_len(N)) {
  for (b in seq_len(N)) {
    if (a == b) next
    if (D_km[a, b] < PARAMS$D_MIN_KM) next
    if (!elegivel_renda[a]) next
    W_cap[a, b] <- W_bruta[a, b] * PARAMS$THETA
  }
}
rownames(W_cap) <- colnames(W_cap) <- regioes$nome
write.csv(W_cap, file.path(proc, "demanda_capturavel.csv"))

cat("\nMacrorregioes elegiveis por renda (>= percentil",
    PARAMS$PERCENTIL_RENDA_MIN, "=", round(corte_renda), "R$):",
    paste(regioes$nome[elegivel_renda], collapse = ", "), "\n")
cat("Demanda capturavel total (viagens/dia, W_ij somado):", round(sum(W_cap)), "\n")
cat("Pares OD elegiveis (W_ij > 0):", sum(W_cap > 0), "de", N * (N - 1), "possiveis\n")
