# app/scripts/08_mapa.R
# Mapa esquematico da rede de vertiportos (p=4, caso de referencia) para o
# relatorio de engenharia. Usa coordenadas UTM Fuso 23S (mesma decisao de
# 00_utils.R: sem sf/rgdal) -- nao e' um basemap real, e' um mapa
# esquematico com as 517 zonas OD coloridas por macrorregiao, os 8
# candidatos a vertiporto e a rede de hubs abertos/fechados em p=4.

suppressMessages(library(lpSolve))
here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))
source(here("scripts", "04_parametros.R"))
source(here("scripts", "06_modelo_hub.R"))

proc <- here("data", "processed")
res_fig <- here("results", "figuras")
dir.create(res_fig, showWarnings = FALSE, recursive = TRUE)

zonas <- read.csv(file.path(proc, "zonas_od2017.csv"))
zonas_macro <- read.csv(file.path(proc, "macrorregioes_zonas.csv"))
regioes <- read.csv(file.path(proc, "macrorregioes_centroides.csv"))
candidatos <- read.csv(file.path(proc, "candidatos_vertiportos.csv"))
W <- as.matrix(read.csv(file.path(proc, "demanda_capturavel.csv"), row.names = 1))
colnames(W) <- rownames(W) <- regioes$nome
tempos <- construir_tempos(regioes, PARAMS)

zonas <- merge(zonas, zonas_macro[, c("zona", "macrorregiao")], by = "zona")

P_REF <- 4
m <- construir_e_resolver(W, tempos, p = P_REF, relax = FALSE, compute_sens = FALSE)
sol <- extrair_solucao(m, regioes)
hubs_abertos <- sol$hubs_abertos_idx

pares_usados <- sol$detalhe_od[sol$detalhe_od$hub_embarque != sol$detalhe_od$hub_desembarque | TRUE, ]
# agrega fluxo por par de hub (k,l) realmente usado
fluxo_kl <- aggregate(W_ij ~ hub_embarque + hub_desembarque, data = pares_usados, sum)
fluxo_kl <- fluxo_kl[fluxo_kl$hub_embarque != "" & fluxo_kl$hub_desembarque != "", ]

paleta <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a",
            "#66a61e", "#e6ab02", "#a6761d", "#666666")

km_x <- zonas$utm_x / 1000
km_y <- zonas$utm_y / 1000
reg_km_x <- regioes$utm_x / 1000
reg_km_y <- regioes$utm_y / 1000
cand_km_x <- candidatos$utm_x / 1000
cand_km_y <- candidatos$utm_y / 1000

png(file.path(res_fig, "mapa_rede_p4.png"), width = 1400, height = 1300, res = 150)
par(mar = c(4, 4, 3, 1))
plot(km_x, km_y, col = adjustcolor(paleta[zonas$macrorregiao], alpha.f = 0.35), pch = 16, cex = 0.5,
     xlab = "UTM E (km, fuso 23S)", ylab = "UTM N (km, fuso 23S)",
     main = sprintf("Rede de vertiportos recomendada (p=%d) -- RMSP", P_REF),
     asp = 1)

# linhas de rede: so entre pares de hub efetivamente usados por algum OD
if (nrow(fluxo_kl) > 0) {
  nome_para_idx <- setNames(seq_len(nrow(regioes)), regioes$nome)
  for (r in seq_len(nrow(fluxo_kl))) {
    k <- nome_para_idx[[fluxo_kl$hub_embarque[r]]]
    l <- nome_para_idx[[fluxo_kl$hub_desembarque[r]]]
    if (is.na(k) || is.na(l) || k == l) next
    lwd_r <- 0.5 + 4 * fluxo_kl$W_ij[r] / max(fluxo_kl$W_ij)
    segments(reg_km_x[k], reg_km_y[k], reg_km_x[l], reg_km_y[l],
             col = "gray30", lwd = lwd_r)
  }
}

# candidatos: abertos (triangulo cheio) vs fechados (circulo vazio)
aberto <- seq_len(nrow(regioes)) %in% hubs_abertos
points(cand_km_x, cand_km_y, pch = ifelse(aberto, 17, 1),
       col = ifelse(aberto, "black", "gray50"),
       cex = ifelse(aberto, 2.2, 1.6), lwd = 2)
text(cand_km_x, cand_km_y, labels = regioes$nome, pos = 3, cex = 0.75, font = ifelse(aberto, 2, 1))

legend("bottomleft", legend = c("Vertiporto aberto (p=4)", "Candidato nao aberto",
                                  "Zona OD (cor = macrorregiao)"),
       pch = c(17, 1, 16), col = c("black", "gray50", "gray40"),
       pt.cex = c(2, 1.6, 1), bty = "n", cex = 0.8)

dev.off()
cat("Mapa salvo em", file.path(res_fig, "mapa_rede_p4.png"), "\n")
cat("Hubs abertos (p=4):", paste(regioes$nome[hubs_abertos], collapse = ", "), "\n")
