# app/scripts/run_all.R
# Roda o pipeline completo, do dado bruto (app/data/raw/) ate' os
# resultados (app/results/), na ordem correta. Rodar a partir da raiz do
# repositorio: `Rscript app/scripts/run_all.R`.

message(">>> 01_prepare_zonas.R")
source("app/scripts/01_prepare_zonas.R")

message("\n>>> 02_macrorregioes.R")
source("app/scripts/02_macrorregioes.R")

message("\n>>> 03_candidatos.R")
source("app/scripts/03_candidatos.R")

message("\n>>> 05_demanda.R")
source("app/scripts/05_demanda.R")

message("\n>>> 07_experimentos.R (relaxacao, dual, sensibilidade, curva de implantacao)")
source("app/scripts/07_experimentos.R")

message("\n>>> Pipeline completo. Ver app/results/tabelas/ e app/results/figuras/.")
