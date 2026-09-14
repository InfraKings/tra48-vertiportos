# app/scripts/03_candidatos.R
# Monta o conjunto de locais candidatos a vertiporto: 1 candidato por
# macrorregiao (decisao: mesma granularidade da demanda, ver
# app/formulacao.md "Reducao de instancia"). Para cada macrorregiao, o
# candidato e' o heliponto registrado na ANAC (RMSP, app/data/raw/
# anac_helipontos_rmsp_*.csv) mais proximo do centroide ponderado por
# demanda da macrorregiao. Macrorregioes sem heliponto registrado usam o
# proprio centroide de demanda como candidato provisorio (marcado
# fonte="centroide_demanda_proxy" -- ver handoff, e' uma limitacao
# assumida explicitamente, nao um heliponto real).
#
# Conversao lon/lat (WGS84, ANAC) -> UTM 23S (metros) por formula fechada
# (Transversa de Mercator), para poder comparar com os centroides de zona
# OD2017 (ja em UTM). Evita depender de sf/proj4/rgdal.

here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))

## Conversao WGS84 lon/lat -> UTM zona 23S (elipsoide GRS80/WGS84) ----------
latlon_to_utm23s <- function(lon, lat) {
  a <- 6378137.0
  f <- 1 / 298.257223563
  k0 <- 0.9996
  e2 <- f * (2 - f)
  ep2 <- e2 / (1 - e2)
  lon0 <- -45 * pi / 180  # meridiano central fuso 23
  lat_r <- lat * pi / 180
  lon_r <- lon * pi / 180
  N <- a / sqrt(1 - e2 * sin(lat_r)^2)
  T <- tan(lat_r)^2
  C <- ep2 * cos(lat_r)^2
  A <- cos(lat_r) * (lon_r - lon0)
  M <- a * ((1 - e2 / 4 - 3 * e2^2 / 64 - 5 * e2^3 / 256) * lat_r
            - (3 * e2 / 8 + 3 * e2^2 / 32 + 45 * e2^3 / 1024) * sin(2 * lat_r)
            + (15 * e2^2 / 256 + 45 * e2^3 / 1024) * sin(4 * lat_r)
            - (35 * e2^3 / 3072) * sin(6 * lat_r))
  x <- k0 * N * (A + (1 - T + C) * A^3 / 6 +
                   (5 - 18 * T + T^2 + 72 * C - 58 * ep2) * A^5 / 120) + 500000
  y <- k0 * (M + N * tan(lat_r) * (A^2 / 2 + (5 - T + 9 * C + 4 * C^2) * A^4 / 24 +
                                      (61 - 58 * T + T^2 + 600 * C - 330 * ep2) * A^6 / 720))
  # hemisferio sul: soma falso norte
  y <- y + 10000000
  data.frame(utm_x = x, utm_y = y)
}

proc <- here("data", "processed")
raw <- here("data", "raw")

regioes <- read.csv(file.path(proc, "macrorregioes_centroides.csv"))
heli <- read.csv(file.path(raw, "anac_helipontos_rmsp_2020-09-11.csv"))

utm <- latlon_to_utm23s(heli$lon, heli$lat)
heli$utm_x <- utm$utm_x
heli$utm_y <- utm$utm_y

## Atribui cada heliponto a' macrorregiao mais proxima -----------------------
heli$macrorregiao <- sapply(seq_len(nrow(heli)), function(i) {
  d <- dist_utm_km(heli$utm_x[i], heli$utm_y[i], regioes$utm_x, regioes$utm_y)
  which.min(d)
})

## Para cada macrorregiao, escolhe o heliponto mais proximo do centroide de
## demanda (dentre os atribuidos a ela) como candidato a vertiporto --------
candidatos <- do.call(rbind, lapply(seq_len(nrow(regioes)), function(r) {
  sub <- heli[heli$macrorregiao == r, ]
  cx <- regioes$utm_x[r]; cy <- regioes$utm_y[r]
  if (nrow(sub) == 0) {
    return(data.frame(
      macrorregiao = r, nome_candidato = paste0("Centroide de demanda — ", regioes$nome[r]),
      municipio = regioes$municipios[r], utm_x = cx, utm_y = cy,
      lon = NA, lat = NA, fonte = "centroide_demanda_proxy",
      dist_ao_centroide_km = 0
    ))
  }
  d <- dist_utm_km(sub$utm_x, sub$utm_y, cx, cy)
  best <- sub[which.min(d), ]
  data.frame(
    macrorregiao = r, nome_candidato = best$nome, municipio = best$municipio,
    utm_x = best$utm_x, utm_y = best$utm_y, lon = best$lon, lat = best$lat,
    fonte = "anac_heliponto", dist_ao_centroide_km = min(d)
  )
}))

candidatos <- merge(candidatos, regioes[, c("macrorregiao", "nome")], by = "macrorregiao")
names(candidatos)[names(candidatos) == "nome"] <- "nome_macrorregiao"
candidatos <- candidatos[order(candidatos$macrorregiao), ]

out <- file.path(proc, "candidatos_vertiportos.csv")
write.csv(candidatos, out, row.names = FALSE)
cat("Candidatos por macrorregiao:\n")
print(candidatos[, c("macrorregiao", "nome_macrorregiao", "nome_candidato", "fonte",
                      "dist_ao_centroide_km")])
cat("\nHelipontos RMSP total:", nrow(heli), " | atribuidos por macrorregiao:\n")
print(table(heli$macrorregiao))
