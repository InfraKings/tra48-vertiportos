# Fontes de dados brutos — app/data/raw/

Todos os arquivos nesta pasta são cópias, sem alteração de conteúdo (apenas
recodificação de nome de arquivo para ASCII em dois casos, ver nota), de
fontes públicas oficiais baixadas em 2026-09-14. Não são dados fabricados.

## 1. Pesquisa Origem e Destino 2017 — Metrô de São Paulo

- **Origem**: Portal da Transparência do Metrô-SP,
  `https://transparencia.metrosp.com.br/dataset/pesquisa-origem-e-destino`
  → arquivo `OD-2017.zip`, download direto:
  `https://transparencia.metrosp.com.br/sites/default/files/OD-2017.zip`
  (42,4 MB, publicado pelo Metrô/SP, última atualização do zip 2021-05-07,
  pesquisa de campo realizada em 2017).
- **Cobertura**: Região Metropolitana de São Paulo (39 municípios), 517
  zonas de pesquisa OD (menores na região central do município de SP,
  maiores na periferia/outros municípios).
- **O que foi extraído do zip** (o zip completo, ~190 MB descompactado, com
  microdados .dbf/.sav, manuais e mapas MapInfo, **não** foi versionado no
  repositório — só os arquivos abaixo, que já são o suficiente para o
  recorte agregado por zona usado no modelo):
  - `Tab01_OD2017.xlsx` — Tabela 1: dados gerais por zona (domicílios,
    população, empregos, viagens produzidas/atraídas, área em ha).
  - `Tab06_OD2017.xlsx` — Tabela 6: renda total, renda média familiar,
    renda per capita e renda mediana familiar por zona de residência.
  - `Tab25_OD2017.xlsx` — Tabela 25: matriz de viagens diárias por
    **transporte individual motorizado** (carro/táxi/moto como motorista
    ou passageiro) entre as 517 zonas de origem e destino. Escolhida como
    base de demanda em vez da Tabela 30 (todos os modos) porque a
    mobilidade aérea urbana compete, na literatura, primariamente com o
    transporte individual motorizado (ver `app/literatura.md`), não com
    ônibus/metrô/a pé/bicicleta.
  - `Zonas_2017.MIF` / `Zonas_2017.MID` — geometria (MapInfo Interchange
    Format, texto plano) e atributos (zona, nome, município, distrito,
    área) dos polígonos das 517 zonas OD 2017. Usados para calcular
    centroides sem depender de bibliotecas de geoprocessamento pesadas
    (sf/rgdal não instaladas nesta sessão) — ver decisão registrada sobre
    o parser MIF próprio em `app/scripts/01_prepare_zonas.R`.
- **Formato**: Excel (.xlsx) para as tabelas agregadas; texto plano
  (MapInfo MIF/MID) para a geometria.
- **Limitações conhecidas**:
  - 2017 é a pesquisa completa mais recente. Há uma "Pesquisa Origem e
    Destino 2023" mais nova (`metro.sp.gov.br/pesquisa-od`), mas em
    2026-09-14 o portal da transparência só listava a base tratada de
    2023 sem o mesmo conjunto de tabelas agregadas por zona já consolidado
    (ou o acesso não foi localizado dentro do tempo desta sessão). Optamos
    por 2017 por ser a base íntegra, documentada e testada. Isso é uma
    decisão registrada (defasagem de ~9 anos entre a pesquisa e o projeto,
    período que inclui a pandemia de COVID-19, que alterou padrões de
    mobilidade).
  - A geometria de zonas está em projeção UTM Fuso 23S (não confirmamos o
    datum exato — SAD69 ou Córrego Alegre, ambos usuais em bases
    municipais de SP da época; a diferença entre eles é da ordem de
    dezenas de metros, irrelevante na escala de agregação em
    macrorregiões usada no modelo).
  - A Tabela 25 mede viagens **diárias médias** (dia útil típico de 2017);
    não há decomposição por hora do dia, então o modelo não distingue
    pico de fora-pico.

## 2. Helipontos — ANAC (Agência Nacional de Aviação Civil)

- **Origem**: Dados Abertos ANAC, "Lista de aeródromos privados — Formato
  CSV", helipontos:
  `https://www.anac.gov.br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aerodromos/lista-de-aerodromos-privados/aerodromos-lista-de-aerodromos-privados-formato-csv/helipontos.csv/@@download/file/Helipontos.csv`
- **Cobertura**: todos os helipontos privados registrados na ANAC no
  Brasil; filtramos aqui para os 39 municípios da RMSP (290 registros,
  sendo 192 no município de São Paulo).
- **Formato**: CSV (`;`-separado, coordenadas em graus/minutos/segundos)
  — convertido para graus decimais e filtrado por município neste
  processo; arquivo salvo é o **filtro RMSP já convertido**
  (`anac_helipontos_rmsp_2020-09-11.csv`), não o CSV nacional bruto (que
  tem ~1260 linhas e cobre o Brasil inteiro — mantido fora do repo por não
  ser específico ao recorte do projeto; a URL acima permite reobtê-lo).
- **Data de referência do próprio arquivo ANAC**: "Última atualização:
  11/09/2020" (primeira linha do CSV original) — é um retrato estático
  publicado pela ANAC, não uma consulta em tempo real; nomeamos o arquivo
  com essa data para deixar isso explícito.
- **Limitações conhecidas**:
  - É a lista de helipontos **privados**; não inclui os poucos
    aeródromos/heliportos públicos, nem o Aeroporto de Congonhas (que é
    aeródromo público, listado em outro dataset da ANAC não baixado nesta
    sessão).
  - Registro de heliponto ≠ viabilidade de virar vertiporto: são só a
    pista/rampa de pouso de um edifício ou hospital, sem infraestrutura de
    recarga elétrica, área de espera de passageiros em escala comercial,
    etc. Tratamos aqui como **proxy de local fisicamente viável e já
    licenciado para pouso de aeronave de asa rotativa em área urbana
    densa** — não como vertiporto pronto. Isso é uma decisão registrada
    (ver handoff), não um fato assumido silenciosamente.
  - Coordenadas informadas pelo operador no processo de licenciamento
    (não são um levantamento GPS independente da ANAC); erro de poucos
    metros a dezenas de metros é possível, irrelevante na escala do
    modelo (macrorregiões).
