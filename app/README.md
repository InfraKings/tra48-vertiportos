# app/ — Camada A (substantiva): localização de vertiportos na RMSP

Modelo de Programação Operacional para o Projeto B1 (TRA-48, ITA):
localização de vertiportos para eVTOL/UAM na Região Metropolitana de São
Paulo. Este diretório é a camada substantiva (dados, formulação, código,
resultados) — a governança do projeto (metas, decisões, experimentos
registrados) fica em `governanca/`, fora deste diretório.

## Como ler este diretório

1. `literatura.md` — revisão de literatura curta (6 referências) que
   fundamenta a escolha de formulação e os parâmetros de demanda.
2. `formulacao.md` — formulação matemática completa (conjuntos, parâmetros,
   variáveis, objetivo, restrições), com a justificativa de cada elemento e
   a decisão de redução de instância.
3. `data/raw/FONTES.md` — origem, formato, cobertura e limitações de cada
   fonte de dado bruto usada.
4. `scripts/` — pipeline em R, executável do zero.
5. `results/` — tabelas e figura produzidas pelo pipeline (as 4 análises
   obrigatórias: relaxação linear, dual, sensibilidade, curva de
   implantação).

## Como reproduzir do zero

Pré-requisitos: R com os pacotes `lpSolve` e `readxl` instalados (ambos já
disponíveis no ambiente em que este projeto foi desenvolvido; não há
dependência de `sf`/`rgdal`/outras bibliotecas de geoprocessamento — ver
justificativa em `scripts/00_utils.R`).

```bash
# a partir da raiz do repositorio (tra48-vertiportos/)
Rscript app/scripts/run_all.R
```

Isso roda, em ordem, todo o pipeline:

| Script | O que faz | Entrada | Saída |
|---|---|---|---|
| `00_utils.R` | Funções auxiliares (parser MIF, distância UTM, k-means ponderado) | — | — |
| `01_prepare_zonas.R` | Centroides das 517 zonas OD2017 + dados gerais + renda | `data/raw/Zonas_2017.MIF/MID`, `Tab01`, `Tab06` | `data/processed/zonas_od2017.csv` |
| `02_macrorregioes.R` | Agrega as 517 zonas em 8 macrorregiões (k-means ponderado por viagens produzidas) | `zonas_od2017.csv` | `macrorregioes_zonas.csv`, `macrorregioes_centroides.csv` |
| `03_candidatos.R` | Escolhe 1 heliponto ANAC por macrorregião como candidato a vertiporto | `data/raw/anac_helipontos_rmsp_*.csv`, macrorregiões | `candidatos_vertiportos.csv` |
| `04_parametros.R` | Parâmetros assumidos (θ, velocidades, limiares) — só definições, não roda nada | — | — |
| `05_demanda.R` | Agrega a Tabela 25 (individual motorizado) para 8x8 e aplica a hipótese de demanda capturável | `Tab25_OD2017.xlsx`, macrorregiões | `demanda_macrorregioes_bruta.csv`, `demanda_capturavel.csv` |
| `06_modelo_hub.R` | Funções que montam e resolvem o MILP (usadas pelos scripts de experimento, não roda sozinho) | — | — |
| `07_experimentos.R` | As 4 análises obrigatórias + monetização ilustrativa | tudo acima | `results/tabelas/*.csv`, `results/figuras/curva_implantacao.png` |

Tempo total do pipeline: poucos segundos (o modelo reduzido a 8
macrorregiões resolve em < 0,1 s por chamada ao `lpSolve`; o script de
experimentos chama o solver ~30 vezes).

## Resultado principal (resumo — ver `results/tabelas/` para os números
completos e `formulacao.md` para as ressalvas)

- 8 macrorregiões (agregação ponderada por demanda das 517 zonas OD2017),
  1 candidato a vertiporto por região (heliponto ANAC real mais próximo do
  centroide de demanda).
- Demanda capturável estimada: ~108 mil viagens/dia (cenário-base: θ=5%,
  distância mínima 8 km, renda de origem no terço superior).
- `p=1` é inviável no modelo (nenhum voo é possível com 1 só vertiporto).
  `p=2` produz economia de tempo **negativa** (pior que não ter UAM) — a
  rede mínima força rotas ruins. A economia de tempo só fica positiva a
  partir de `p=3`, e os retornos marginais caem monotonicamente até `p=8`
  (ver `results/figuras/curva_implantacao.png`).
- A relaxação linear é **inteira** (gap 0%) para todo `p` testado nesta
  instância — achado registrado e discutido em `results/tabelas/log_experimentos.txt`,
  não generalizado sem ressalva para instâncias maiores/capacitadas.

## Limitações reconhecidas (lista completa em `formulacao.md` §7)

Sem restrição de capacidade por vertiporto, sem custo fixo de implantação
(logo `p` é exógeno, não otimizado por custo-benefício), demanda capturável
via fração fixa `θ` (não um modelo de escolha de modo sensível a preço),
instância reduzida a 8 macrorregiões (perde resolução espacial fina), e a
velocidade terrestre da linha de base usa o mesmo valor da via de
acesso/egresso (tende a **superestimar** o benefício da UAM em pares OD
distantes, que na realidade teriam acesso a vias expressas mais rápidas).
