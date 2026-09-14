# app/scripts/01_prepare_zonas.R
# Le a geometria (MIF/MID) das 517 zonas OD2017, calcula centroides UTM, e
# junta com Tabela 1 (viagens produzidas/atraidas, populacao, empregos) e
# Tabela 6 (renda media familiar por zona de residencia). Saida:
# app/data/processed/zonas_od2017.csv (517 linhas, 1 por zona).

suppressMessages({
  library(readxl)
})

here <- function(...) file.path("app", ...)
source(here("scripts", "00_utils.R"))

raw <- here("data", "raw")
proc <- here("data", "processed")
dir.create(proc, showWarnings = FALSE, recursive = TRUE)

## 1. Geometria: centroides das 517 zonas (MIF, texto plano) ----------------
geo <- ler_centroides_mif(file.path(raw, "Zonas_2017.MIF"))

mid <- read.csv(file.path(raw, "Zonas_2017.MID"), header = FALSE,
                 col.names = c("zona", "nome_zona", "cod_municipio",
                               "nome_municipio", "cod_distrito", "nome_distrito",
                               "area_ha"),
                 fileEncoding = "latin1", stringsAsFactors = FALSE)
stopifnot(nrow(mid) == nrow(geo))
zonas_geo <- cbind(mid, geo)

## 2. Tabela 1 — dados gerais por zona ---------------------------------------
tab01 <- read_excel(file.path(raw, "Tab01_OD2017.xlsx"), sheet = 1, col_names = FALSE)
tab01 <- as.data.frame(tab01)
col1 <- suppressWarnings(as.numeric(tab01[[1]]))
r0 <- which(!is.na(col1) & col1 == 1)[1]
tab01d <- tab01[r0:(r0 + 516), 1:11]
names(tab01d) <- c("zona", "nome_zona_tab", "domicilios", "familias", "populacao",
                    "matriculas_escolares", "empregos", "automoveis_particulares",
                    "viagens_produzidas", "viagens_atraidas", "area_ha_tab")
tab01d[] <- lapply(tab01d, function(col) if (is.character(col)) col else col)
for (cc in c("zona", "domicilios", "familias", "populacao", "matriculas_escolares",
             "empregos", "automoveis_particulares", "viagens_produzidas",
             "viagens_atraidas", "area_ha_tab")) {
  tab01d[[cc]] <- as.numeric(tab01d[[cc]])
}

## 3. Tabela 6 — renda por zona de residencia --------------------------------
tab06 <- read_excel(file.path(raw, "Tab06_OD2017.xlsx"), sheet = 1, col_names = FALSE)
tab06 <- as.data.frame(tab06)
col1b <- suppressWarnings(as.numeric(tab06[[1]]))
r0b <- which(!is.na(col1b) & col1b == 1)[1]
tab06d <- tab06[r0b:(r0b + 516), 1:5]
names(tab06d) <- c("zona", "renda_total", "renda_media_familiar", "renda_per_capita",
                    "renda_mediana_familiar")
for (cc in names(tab06d)) tab06d[[cc]] <- as.numeric(tab06d[[cc]])

## 4. Junta tudo por numero de zona ------------------------------------------
zonas <- merge(zonas_geo, tab01d, by = "zona", all.x = TRUE)
zonas <- merge(zonas, tab06d, by = "zona", all.x = TRUE)
zonas <- zonas[order(zonas$zona), ]

stopifnot(nrow(zonas) == 517, !any(duplicated(zonas$zona)))

out <- here("data", "processed", "zonas_od2017.csv")
write.csv(zonas, out, row.names = FALSE)
cat("OK -", nrow(zonas), "zonas ->", out, "\n")
cat("Resumo viagens_produzidas total (RMSP, dia util 2017):",
    format(sum(zonas$viagens_produzidas, na.rm = TRUE), big.mark = "."), "\n")
cat("NAs renda_media_familiar:", sum(is.na(zonas$renda_media_familiar)), "\n")
