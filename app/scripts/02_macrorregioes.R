# app/scripts/02_macrorregioes.R
# Reducao de instancia (decisao registrada, ver handoff): agrega as 517
# zonas OD2017 em N_REGIOES macrorregioes via k-means ponderado (peso =
# viagens produzidas, Tabela 1) sobre os centroides UTM. Isso e' necessario
# porque a formulacao de hub location com alocacao multipla usada em
# app/formulacao.md tem contagem de variaveis O(n_regioes^4); com as 517
# zonas originais isso e' computacionalmente inviavel para o lpSolve (que
# monta a matriz de restricoes densa em memoria). Ver app/formulacao.md
# secao "Reducao de instancia" para a conta completa de variaveis/restricoes
# e a justificativa do valor de N_REGIOES escolhido.

here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))

N_REGIOES <- 8  # decisao: ver app/formulacao.md

proc <- here("data", "processed")
zonas <- read.csv(file.path(proc, "zonas_od2017.csv"))

coords <- as.matrix(zonas[, c("utm_x", "utm_y")])
pesos <- zonas$viagens_produzidas
pesos[is.na(pesos) | pesos <= 0] <- 1

km <- weighted_kmeans(coords, pesos, k = N_REGIOES, seed = 42)
zonas$macrorregiao <- km$cluster

## Centroide ponderado (por viagens produzidas) de cada macrorregiao --------
regioes <- do.call(rbind, lapply(seq_len(N_REGIOES), function(r) {
  idx <- which(zonas$macrorregiao == r)
  w <- pesos[idx]
  data.frame(
    macrorregiao = r,
    n_zonas = length(idx),
    utm_x = sum(zonas$utm_x[idx] * w) / sum(w),
    utm_y = sum(zonas$utm_y[idx] * w) / sum(w),
    viagens_produzidas = sum(zonas$viagens_produzidas[idx], na.rm = TRUE),
    populacao = sum(zonas$populacao[idx], na.rm = TRUE),
    renda_media_familiar = weighted.mean(zonas$renda_media_familiar[idx], w, na.rm = TRUE),
    municipios = paste(sort(unique(zonas$nome_municipio[idx])), collapse = "; ")
  )
}))

## Nome descritivo (municipio/distrito dominante por viagens) ---------------
nomes <- sapply(seq_len(N_REGIOES), function(r) {
  idx <- which(zonas$macrorregiao == r)
  tb <- tapply(zonas$viagens_produzidas[idx], zonas$nome_distrito[idx], sum, na.rm = TRUE)
  nm <- names(tb)[which.max(tb)]
  mun <- tapply(zonas$viagens_produzidas[idx], zonas$nome_municipio[idx], sum, na.rm = TRUE)
  mundom <- names(mun)[which.max(mun)]
  if (mundom != "São Paulo") return(mundom)
  nm
})
regioes$nome <- nomes

write.csv(zonas[, c("zona", "nome_zona", "nome_municipio", "macrorregiao")],
          file.path(proc, "macrorregioes_zonas.csv"), row.names = FALSE)
write.csv(regioes, file.path(proc, "macrorregioes_centroides.csv"), row.names = FALSE)

cat("Macrorregioes (N =", N_REGIOES, "):\n")
print(regioes[, c("macrorregiao", "nome", "n_zonas", "populacao", "viagens_produzidas",
                   "renda_media_familiar")])
cat("\nSoma viagens_produzidas (macrorregioes) vs total zonas:",
    sum(regioes$viagens_produzidas), "vs", sum(zonas$viagens_produzidas, na.rm = TRUE), "\n")
