# app/scripts/00_utils.R
# Funcoes auxiliares compartilhadas pelo pipeline. Nao depende de pacotes de
# geoprocessamento (sf/rgdal/sp) -- decisao registrada: essas bibliotecas nao
# estavam disponiveis nesta sessao e sua instalacao (compilacao de GDAL/GEOS)
# e pesada e propensa a falhar sem internet/Homebrew configurados. Todas as
# contas geometricas usam coordenadas UTM (metros, planas) ou distancia
# euclidiana simples, suficiente na escala de uma unica zona UTM (23S).

#' Le um arquivo MIF (MapInfo Interchange Format, texto plano) de poligonos
#' e retorna o centroide (area-weighted, formula do poligono) de cada
#' feature, na ordem em que aparecem no arquivo. Faz parsing minimo: nao
#' interpreta CoordSys nem estilos, so extrai as coordenadas dos vertices de
#' cada bloco "Region".
ler_centroides_mif <- function(path_mif) {
  ln <- readLines(path_mif, warn = FALSE)
  data_start <- which(trimws(ln) == "Data")
  stopifnot(length(data_start) == 1)
  body <- ln[(data_start + 1):length(ln)]

  region_idx <- grep("^Region", body)
  n <- length(region_idx)
  cx <- numeric(n); cy <- numeric(n); area_tot <- numeric(n)

  poly_centroid <- function(x, y) {
    # formula padrao do centroide de poligono (shoelace), assume anel simples
    n <- length(x)
    if (n < 3) return(c(mean(x), mean(y), 0))
    x2 <- c(x, x[1]); y2 <- c(y, y[1])
    cross <- x2[1:n] * y2[2:(n + 1)] - x2[2:(n + 1)] * y2[1:n]
    A <- sum(cross) / 2
    if (abs(A) < 1e-9) return(c(mean(x), mean(y), 0))
    Cx <- sum((x2[1:n] + x2[2:(n + 1)]) * cross) / (6 * A)
    Cy <- sum((y2[1:n] + y2[2:(n + 1)]) * cross) / (6 * A)
    c(Cx, Cy, abs(A))
  }

  for (i in seq_len(n)) {
    start <- region_idx[i]
    # a linha e' "Region  <n_sub>" -- o numero de sub-poligonos vem na mesma linha
    n_sub <- as.integer(trimws(sub("^Region", "", body[start])))
    pos <- start + 1
    best <- NULL
    for (s in seq_len(n_sub)) {
      npts <- as.integer(trimws(body[pos]))
      pos <- pos + 1
      coords <- body[pos:(pos + npts - 1)]
      pos <- pos + npts
      xy <- do.call(rbind, lapply(strsplit(trimws(coords), "\\s+"), function(v) as.numeric(v)))
      pc <- poly_centroid(xy[, 1], xy[, 2])
      if (is.null(best) || pc[3] > best[3]) best <- pc  # fica com o maior anel (ilha principal)
    }
    cx[i] <- best[1]; cy[i] <- best[2]; area_tot[i] <- best[3]
  }
  data.frame(utm_x = cx, utm_y = cy, area_m2_geom = area_tot)
}

#' Distancia euclidiana plana (metros) entre pontos UTM -- valida para a
#' escala de uma cidade dentro de um unico fuso UTM (erro de projecao
#' desprezivel frente a agregacao em macrorregioes).
dist_utm_km <- function(x1, y1, x2, y2) {
  sqrt((x1 - x2)^2 + (y1 - y2)^2) / 1000
}

#' K-means ponderado (algoritmo de Lloyd) em coordenadas 2D, pesos >= 0.
#' Usado para agregar as 517 zonas OD em macrorregioes ponderadas por
#' viagens produzidas (decisao: agregacao geometrica ponderada por demanda,
#' nao so por area/contiguidade administrativa -- ver handoff).
weighted_kmeans <- function(coords, weights, k, iter.max = 100, seed = 42) {
  set.seed(seed)
  n <- nrow(coords)
  weights[weights <= 0] <- 1e-6
  init_idx <- sample(n, k, prob = weights)
  centers <- as.matrix(coords[init_idx, , drop = FALSE])
  assign <- rep(1L, n)
  for (it in seq_len(iter.max)) {
    d2 <- matrix(0, n, k)
    for (j in seq_len(k)) {
      d2[, j] <- (coords[, 1] - centers[j, 1])^2 + (coords[, 2] - centers[j, 2])^2
    }
    new_assign <- apply(d2, 1, which.min)
    new_centers <- centers
    for (j in seq_len(k)) {
      idx <- which(new_assign == j)
      if (length(idx) == 0) next
      w <- weights[idx]
      new_centers[j, ] <- c(
        sum(coords[idx, 1] * w) / sum(w),
        sum(coords[idx, 2] * w) / sum(w)
      )
    }
    move <- max(abs(new_centers - centers))
    centers <- new_centers
    assign <- new_assign
    if (move < 1e-3) break
  }
  list(centers = centers, cluster = assign, iter = it)
}
