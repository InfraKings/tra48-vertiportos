-- dump.sql -- historia legivel do banco de governanca, gerada por ./gov update.
-- Fonte de verdade e governanca/projeto.duckdb; este arquivo e derivado.
-- Gerado em 2026-09-15T09:45:05.040127

-- TRA-48 Projeto B1 -- Camada B (governanca)
-- Esquema do banco de governanca / grafo executivo.
-- Fonte: Projeto_TRA48.pdf, cap. 5.3 ("O que deve ser registrado") e 5.4 ("O grafo executivo").
--
-- Toda entidade abaixo e um NO do grafo executivo. A tabela `relacoes`, no
-- final, e a lista de ARESTAS que liga esses nos ("esta decisao usou esta
-- fonte", "este script produziu este resultado", "este experimento apoia
-- esta conclusao"). O grafo nao e uma visualizacao a parte: e a leitura
-- relacional deste proprio esquema.
--
-- Escrita sempre via ./gov (governanca/scripts/gov.py). Nunca editar
-- projeto.duckdb diretamente -- ver claude.md e .claude/agents/governanca.md.

-- ---------------------------------------------------------------------
-- Integrantes: nunca se presume autoria. Toda entidade abaixo carrega um
-- responsavel (--resp) que deve ser um destes tres.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS integrantes (
    nome    VARCHAR PRIMARY KEY,
    email   VARCHAR
);

INSERT OR IGNORE INTO integrantes (nome, email) VALUES
    ('Vitor', NULL),
    ('Gilberto', NULL),
    ('Guilherme', NULL);

-- ---------------------------------------------------------------------
-- Metas (2 a 4): os objetivos do projeto, aos quais tudo mais se vincula.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_metas START 1;
CREATE TABLE IF NOT EXISTS metas (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_metas'),
    descricao       VARCHAR NOT NULL,
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp,
    commit_hash     VARCHAR
);

-- ---------------------------------------------------------------------
-- Tarefas: trabalho a fazer, com responsavel e prazo.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_tarefas START 1;
CREATE TABLE IF NOT EXISTS tarefas (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_tarefas'),
    descricao       VARCHAR NOT NULL,
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    prazo           DATE,
    meta_id         INTEGER REFERENCES metas(id),
    status          VARCHAR NOT NULL DEFAULT 'aberta' CHECK (status IN ('aberta', 'em_andamento', 'concluida', 'cancelada')),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp,
    concluida_em    TIMESTAMP,
    commit_hash     VARCHAR
);

-- ---------------------------------------------------------------------
-- Pendencias: o que trava o projeto e depende de terceiros ou de definicao.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_pendencias START 1;
CREATE TABLE IF NOT EXISTS pendencias (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_pendencias'),
    descricao       VARCHAR NOT NULL,
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    meta_id         INTEGER REFERENCES metas(id),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp,
    resolvida_em    TIMESTAMP,
    resolucao       VARCHAR,
    commit_hash     VARCHAR
);

-- ---------------------------------------------------------------------
-- Decisoes: toda escolha metodologica -- recorte, limiares, valor do
-- tempo, formulacao, agregacao de zonas, solver -- com justificativa e
-- alternativas descartadas (5.3). Sem esses dois campos preenchidos, a
-- decisao nao satisfaz a regra fundamental do projeto.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_decisoes START 1;
CREATE TABLE IF NOT EXISTS decisoes (
    id                          INTEGER PRIMARY KEY DEFAULT nextval('seq_decisoes'),
    descricao                   VARCHAR NOT NULL,
    justificativa               VARCHAR NOT NULL,
    alternativas_descartadas    VARCHAR NOT NULL,
    resp                        VARCHAR NOT NULL REFERENCES integrantes(nome),
    meta_id                     INTEGER REFERENCES metas(id),
    criado_em                   TIMESTAMP NOT NULL DEFAULT current_timestamp,
    commit_hash                 VARCHAR
);

-- ---------------------------------------------------------------------
-- Fontes de dados: origem, formato, cobertura, limitacoes (3.2, 5.3).
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_fontes START 1;
CREATE TABLE IF NOT EXISTS fontes_dados (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_fontes'),
    nome            VARCHAR NOT NULL,
    origem          VARCHAR NOT NULL,
    formato         VARCHAR,
    cobertura       VARCHAR,
    limitacoes      VARCHAR NOT NULL,
    credito         VARCHAR, -- outro grupo/fonte externa, se aplicavel (2.6)
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp,
    commit_hash     VARCHAR
);

-- ---------------------------------------------------------------------
-- Arquivos: scripts, mapas, bases derivadas, relatorios.
-- Um arquivo sem decisao_id e um NO ORFAO (5.4/5.7) e aparece na auditoria.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_arquivos START 1;
CREATE TABLE IF NOT EXISTS arquivos (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_arquivos'),
    caminho         VARCHAR NOT NULL,
    descricao       VARCHAR,
    decisao_id      INTEGER REFERENCES decisoes(id),
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp,
    commit_hash     VARCHAR
);

-- ---------------------------------------------------------------------
-- Referencias: artigos e normas utilizados (4.1).
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_referencias START 1;
CREATE TABLE IF NOT EXISTS referencias (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_referencias'),
    citacao         VARCHAR NOT NULL,
    tipo            VARCHAR, -- artigo, norma, livro, etc.
    url_ou_doi      VARCHAR,
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp
);

-- ---------------------------------------------------------------------
-- Experimentos: cada rodada do modelo -- hipotese, parametros, commit,
-- valor da funcao objetivo, gap, tempo de solucao e conclusao (5.3).
-- Uma conclusao sem experimento que a sustente e um defeito de auditoria.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_experimentos START 1;
CREATE TABLE IF NOT EXISTS experimentos (
    id                  INTEGER PRIMARY KEY DEFAULT nextval('seq_experimentos'),
    variante            VARCHAR NOT NULL, -- ex: cobertura, p-mediana, hub-capacitado
    hipotese            VARCHAR NOT NULL,
    parametros          VARCHAR, -- JSON livre (ex: {"p": 8, "vot": 25})
    commit_hash         VARCHAR,
    valor_objetivo      DOUBLE,
    gap                 DOUBLE,
    tempo_solucao_s     DOUBLE,
    conclusao           VARCHAR,
    decisao_id          INTEGER REFERENCES decisoes(id),
    resp                VARCHAR NOT NULL REFERENCES integrantes(nome),
    criado_em           TIMESTAMP NOT NULL DEFAULT current_timestamp
);

-- ---------------------------------------------------------------------
-- Interacoes com IA: o que foi pedido, o que voltou, o que foi aceito e
-- o que foi criticado (5.3, 5.6). critica_humana e OBRIGATORIA e nunca
-- generica -- imposta via CHECK, nao apenas por convencao.
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_ia START 1;
CREATE TABLE IF NOT EXISTS interacoes_ia (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_ia'),
    proposito       VARCHAR NOT NULL, -- ex: formulacao, codigo, analise, texto
    pedido          VARCHAR,
    resposta_resumo VARCHAR,
    aceite          VARCHAR NOT NULL CHECK (aceite IN ('integral', 'parcial', 'descarte')),
    critica_humana  VARCHAR NOT NULL CHECK (
                        length(trim(critica_humana)) > 10
                        AND lower(trim(critica_humana)) NOT IN ('ok', 'ok, sem ressalvas', 'sem ressalvas', 'nenhuma', 'n/a')
                    ),
    resp            VARCHAR NOT NULL REFERENCES integrantes(nome),
    decisao_id      INTEGER REFERENCES decisoes(id),
    experimento_id  INTEGER REFERENCES experimentos(id),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp,
    commit_hash     VARCHAR
);

-- ---------------------------------------------------------------------
-- Relacoes: as ARESTAS do grafo executivo. Liga qualquer no a qualquer
-- no, tipado pela natureza da relacao. E o que permite responder, em um
-- clique, perguntas como "qual script gerou este resultado" (5.4).
--
-- tipo_origem / tipo_destino: 'meta' | 'tarefa' | 'pendencia' | 'decisao'
--   | 'fonte' | 'arquivo' | 'referencia' | 'experimento' | 'ia'
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_relacoes START 1;
CREATE TABLE IF NOT EXISTS relacoes (
    id              INTEGER PRIMARY KEY DEFAULT nextval('seq_relacoes'),
    tipo_origem     VARCHAR NOT NULL,
    id_origem       INTEGER NOT NULL,
    tipo_relacao    VARCHAR NOT NULL, -- ex: 'usa', 'produz', 'apoia', 'depende_de', 'credita'
    tipo_destino    VARCHAR NOT NULL,
    id_destino      INTEGER NOT NULL,
    resp            VARCHAR REFERENCES integrantes(nome),
    criado_em       TIMESTAMP NOT NULL DEFAULT current_timestamp
);

-- ==================== DADOS ====================

-- integrantes (3 linha(s))
INSERT INTO integrantes (nome, email) VALUES ('Gilberto', 'gilberto@tra48.local');
INSERT INTO integrantes (nome, email) VALUES ('Guilherme', 'guilherme@tra48.local');
INSERT INTO integrantes (nome, email) VALUES ('Vitor', 'biasevitor@gmail.com');

-- metas (4 linha(s))
INSERT INTO metas (id, descricao, resp, criado_em, commit_hash) VALUES (1, 'Formular, justificar e resolver computacionalmente um modelo de localizacao de hubs para vertiportos na RMSP, com relaxacao linear, interpretacao do dual e analise de sensibilidade (PDF secao 1.3-1)', 'Vitor', '2026-09-14T14:58:07.965163', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO metas (id, descricao, resp, criado_em, commit_hash) VALUES (2, 'Estimar a demanda capturavel por UAM a partir da Pesquisa OD do Metro de SP e produzir recomendacao defensavel de onde e quantos vertiportos implantar, e quanto isso vale (PDF secao 1.3-2)', 'Vitor', '2026-09-14T14:58:08.152045', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO metas (id, descricao, resp, criado_em, commit_hash) VALUES (3, 'Manter repositorio publico com banco de governanca auditavel, grafo executivo navegavel e analise reprodutivel de ponta a ponta, alimentado ao longo do bimestre (PDF secao 1.3-3, 5.7, 8.4)', 'Vitor', '2026-09-14T14:58:08.332490', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO metas (id, descricao, resp, criado_em, commit_hash) VALUES (4, 'Garantir que cada integrante do grupo seja capaz de explicar e defender qualquer decisao do modelo, do codigo e do relatorio -- inclusive divergencias da IA (PDF secao 1.3-4, 5.6)', 'Vitor', '2026-09-14T14:58:08.503604', '89e3c4ef79a61775dee71b474b8d8e67f673c780');

-- tarefas (1 linha(s))
INSERT INTO tarefas (id, descricao, resp, prazo, meta_id, status, criado_em, concluida_em, commit_hash) VALUES (1, 'Avaliar extensao do modelo com opcao de nao-capturar demanda (arco ''nao-voar'' endogeno) para evitar economia de tempo negativa forcada em p baixo', 'Vitor', '2026-09-16', 1, 'aberta', '2026-09-14T15:24:59.557755', NULL, '89e3c4ef79a61775dee71b474b8d8e67f673c780');

-- pendencias (6 linha(s))
INSERT INTO pendencias (id, descricao, resp, meta_id, criado_em, resolvida_em, resolucao, commit_hash) VALUES (1, 'Link/repositorio-modelo do professor ainda nao distribuido -- por ora seguimos a estrutura propria do cap. 5 do PDF', 'Vitor', NULL, '2026-09-02T09:15:34.453841', NULL, NULL, 'ee7191300d69f67eadabded49ced6667f5cd623d');
INSERT INTO pendencias (id, descricao, resp, meta_id, criado_em, resolvida_em, resolucao, commit_hash) VALUES (2, 'Metas do projeto (2 a 4) ainda nao definidas/registradas no banco -- bloqueia registro de decisoes, tarefas e fontes vinculadas', 'Vitor', NULL, '2026-09-02T09:15:34.645325', '2026-09-14T14:58:13.833034', '4 metas registradas (#1-#4) cobrindo modelagem/resultados, demanda capturavel, governanca/reprodutibilidade e capacidade de defesa do grupo -- ver ''O que se espera ao final'', PDF 1.3', 'ee7191300d69f67eadabded49ced6667f5cd623d');
INSERT INTO pendencias (id, descricao, resp, meta_id, criado_em, resolvida_em, resolucao, commit_hash) VALUES (3, 'Apresentacao oral do grupo ainda nao existe (PDF 6.3) -- precisa cobrir as duas camadas (modelo + processo) e os indicadores minimos comparaveis entre grupos', 'Vitor', NULL, '2026-09-15T09:45:04.147651', NULL, NULL, 'c9c204d40aa6c9845f9be524b0dd68be249b627c');
INSERT INTO pendencias (id, descricao, resp, meta_id, criado_em, resolvida_em, resolucao, commit_hash) VALUES (4, 'Decisoes e criticas de IA registradas ate agora (decisoes #2-#11, interacoes de IA #1-#4) tem autoria Vitor mas ainda nao foram validadas/rediscutidas pelo grupo -- claude.md exige validacao humana da critica antes de vira registro definitivo', 'Vitor', NULL, '2026-09-15T09:45:04.337898', NULL, NULL, 'c9c204d40aa6c9845f9be524b0dd68be249b627c');
INSERT INTO pendencias (id, descricao, resp, meta_id, criado_em, resolvida_em, resolucao, commit_hash) VALUES (5, 'Gilberto e Guilherme ainda sem nenhum commit ou registro proprio no banco de governanca -- contribuicao individual e avaliada por autoria', 'Vitor', NULL, '2026-09-15T09:45:04.526986', NULL, NULL, 'c9c204d40aa6c9845f9be524b0dd68be249b627c');
INSERT INTO pendencias (id, descricao, resp, meta_id, criado_em, resolvida_em, resolucao, commit_hash) VALUES (6, 'Terceiro encontro de acompanhamento com o professor ainda nao agendado (PDF 7.2)', 'Vitor', NULL, '2026-09-15T09:45:04.712651', NULL, NULL, 'c9c204d40aa6c9845f9be524b0dd68be249b627c');

-- decisoes (11 linha(s))
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (1, 'Usar e-mails placeholder (nome@tra48.local) para git commit --author', 'A comunicacao do grupo e via WhatsApp, nao e-mail; git exige um e-mail para identificar autoria de cada commit, mas esse e-mail nao precisa ser real ou alcancavel -- e so um identificador tecnico do commit, sem uso para contato', 'Coletar e-mail real de cada integrante -- descartado porque criaria fricção sem necessidade real: o grupo nao usa e-mail no dia a dia, e o campo do git nao exige que o endereco funcione', 'Vitor', NULL, '2026-09-02T09:15:29.823944', 'ee7191300d69f67eadabded49ced6667f5cd623d');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (2, 'Base de demanda = Tabela 25 da Pesquisa OD 2017 (individual motorizado: carro/taxi/moto), nao a Tabela 30 (todos os modos)', 'UAM compete na literatura primariamente com transporte individual motorizado (carro/taxi/app), nao com onibus/metro/a pe -- ver app/literatura.md refs 4-5 (Booz Allen/NASA 2018, Rimjha & Trani 2021)', 'Tabela 30 completa (todos os modos), que infla a base de demanda incluindo viagens de onibus/metro/a pe que dificilmente migrariam para UAM', 'Vitor', 2, '2026-09-14T15:24:48.645314', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (3, 'Uso da Pesquisa OD 2017 como base, nao a Pesquisa OD 2023 mais recente', 'OD2017 e a pesquisa completa mais recente com o conjunto de tabelas agregadas por zona ja consolidado e testado; a base tratada de 2023 no portal da transparencia nao foi localizada com o mesmo detalhamento dentro do prazo da sessao', 'Migrar para OD2023 assim que o conjunto agregado equivalente for localizado/confirmado -- registrado como limitacao reconhecida, nao descartado definitivamente', 'Vitor', 2, '2026-09-14T15:24:48.827885', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (4, 'Formulacao = p-hub median nao-capacitado de alocacao multipla (Campbell, 1994), linear', 'Representa a interdependencia entre vertiportos exigida pelo enunciado (valor de abrir k depende de quais outros l estao abertos) e e linearizavel, resolvivel com lpSolve disponivel no ambiente', 'Formulacao quadratica de alocacao unica de O''Kelly (1987) -- mais fiel a topologia hub-and-spoke classica mas exige MIQP, solver indisponivel na sessao; cobertura maxima / p-mediana simples -- descartadas por nao capturarem a interdependencia entre hubs exigida no enunciado (PDF 2.2)', 'Vitor', 1, '2026-09-14T15:24:49.011769', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (5, 'Reducao de instancia: 517 zonas OD -> 8 macrorregioes via k-means ponderado por viagens produzidas; mesmo conjunto usado como candidatos', 'A variavel de fluxo do MILP de alocacao multipla cresce O(n^4); testado empiricamente que a matriz densa do lpSolve explode em memoria acima de ~10-12 regioes -- ver app/formulacao.md secao 9', 'Usar as 517 zonas diretamente (instancia inviavel computacionalmente); usar os 96 distritos municipais (ainda grande demais para o solver denso usado)', 'Vitor', 1, '2026-09-14T15:24:49.204406', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (6, 'Candidatos a vertiporto = 1 heliponto ANAC real mais proximo do centroide de demanda de cada macrorregiao', 'Dado publico verificavel, ja licenciado para pouso de aeronave de asa rotativa em area urbana densa -- proxy mais direto de viabilidade aeronautica do que um ponto generico', 'Estacoes de metro/terminais de transporte como proxy de no de acesso terrestre (permitido pelo enunciado, mas nao garante viabilidade de pouso); ponto arbitrario no centroide sem verificacao de viabilidade real', 'Vitor', 1, '2026-09-14T15:24:49.415193', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (7, 'Hipotese de demanda capturavel por UAM = filtro de distancia (par OD >= 8km) x filtro de renda de origem (tercio superior) x fracao comportamental fixa theta=5%', 'Cada componente do filtro tem respaldo na literatura de mercado de UAM (Booz Allen/NASA 2018; Rimjha & Trani 2021) -- viagens curtas nao compensam o overhead de acesso/embarque, e a disposicao a pagar tarifa premium de UAM correlaciona com renda', 'Fracao unica arbitraria sobre toda a matriz OD sem filtro geografico/socioeconomico -- descartada por nao ter fundamentacao e por inflar demanda em pares de curta distancia onde UAM nao compensa', 'Vitor', 2, '2026-09-14T15:24:49.597884', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (8, 'Sem custo fixo de implantacao no objetivo; numero de vertiportos p tratado como parametro exogeno variado na curva de implantacao, nao otimizado endogenamente', 'Nenhuma fonte publica confiavel de custo de implantacao de vertiporto eVTOL no Brasil foi localizada dentro do prazo da sessao', 'Inventar um custo fixo sem fonte verificavel -- descartado por violar a regra de nao fabricar dado (PDF 8.4); manter p exogeno e reportar a curva de implantacao completa (beneficio vs. p) permite ao leitor aplicar seu proprio custo', 'Vitor', 1, '2026-09-14T15:24:49.780181', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (9, 'Modelo sem restricao de capacidade por vertiporto (uncapacitated)', 'Primeira camada e localizacao, nao dimensionamento operacional -- capacidade por vertiporto depende de decisoes de infraestrutura (num. de pads, frequencia de voo) fora do escopo desta rodada', 'Incluir capacidade estimada por analogia a heliponto -- descartada por falta de dado de capacidade real de vertiporto eVTOL; registrada como trabalho futuro em app/formulacao.md', 'Vitor', 1, '2026-09-14T15:24:49.962230', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (10, 'Implementacao em R + lpSolve, sem bibliotecas de geoprocessamento pesadas (sf/rgdal); parser MIF proprio e projecao UTM em R puro', 'sf/rgdal nao estavam instaladas e exigiriam compilacao pesada sem garantia de sucesso no ambiente da sessao; R e a linguagem padrao da disciplina (PDF 4.6) e lpSolve ja estava disponivel', 'Instalar sf/rgdal via compilacao -- descartada por risco de falha/tempo; usar Python com geopandas -- descartada por exigir justificativa registrada de uso de outra linguagem (PDF 4.6), sem necessidade real dado que o parser MIF proprio resolveu o caso de uso', 'Vitor', 1, '2026-09-14T15:24:50.144889', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO decisoes (id, descricao, justificativa, alternativas_descartadas, resp, meta_id, criado_em, commit_hash) VALUES (11, 'Recomendacao final: implantar entre p=4 e p=6 vertiportos, priorizando a rede de p=4 (Sao Bernardo do Campo, Guarulhos, Itaim Bibi, Jardim Paulista)', 'A partir de p=4 a economia marginal por vertiporto adicional ja caiu para menos de 40% do primeiro salto (p=2->3) e continua caindo monotonicamente; em p=7-8 o ganho marginal fica abaixo de 15% do ganho do primeiro vertiporto util, enquanto o custo de implantacao (nao monetizado, decisao #8) certamente nao cai na mesma proporcao -- ver curva de implantacao, experimento #5', 'p=8 (cobertura maxima) -- descartado como recomendacao principal por retorno marginal desproporcionalmente baixo (1984 h-passageiro/dia, a menor marginal de toda a curva); p=2 (minimo viavel) -- descartado por produzir economia de tempo NEGATIVA (achado do experimento #5), pior que nao ter UAM', 'Vitor', 2, '2026-09-15T09:37:04.553638', '324077282fc19261f654b91819323fc6ddd6b312');

-- fontes_dados (2 linha(s))
INSERT INTO fontes_dados (id, nome, origem, formato, cobertura, limitacoes, credito, resp, criado_em, commit_hash) VALUES (1, 'Pesquisa Origem e Destino 2017 -- Metro de Sao Paulo (Tabelas 1, 6, 25 + geometria de zonas)', 'https://transparencia.metrosp.com.br/sites/default/files/OD-2017.zip (Portal da Transparencia Metro-SP)', 'Excel (.xlsx) para tabelas agregadas por zona; MapInfo MIF/MID (texto plano) para geometria das 517 zonas', 'Regiao Metropolitana de Sao Paulo, 39 municipios, 517 zonas OD, pesquisa de campo 2017 (zip atualizado 2021-05-07)', 'Defasagem de ~9 anos (inclui periodo pos-pandemia); Pesquisa OD 2023 mais recente existe mas nao foi localizada com o mesmo conjunto de tabelas agregadas dentro do prazo da sessao (decisao registrada separadamente); datum UTM do shapefile nao confirmado (SAD69 vs Corrego Alegre, diferenca desprezivel na escala de macrorregioes); Tabela 25 mede viagem diaria media, sem decomposicao por hora/pico', NULL, 'Vitor', '2026-09-14T15:24:48.284150', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO fontes_dados (id, nome, origem, formato, cobertura, limitacoes, credito, resp, criado_em, commit_hash) VALUES (2, 'Helipontos privados -- ANAC (Dados Abertos)', 'https://www.anac.gov.br/acesso-a-informacao/dados-abertos/.../helipontos.csv (Lista de aerodromos privados, CSV)', 'CSV separado por ; coordenadas em graus/minutos/segundos, convertidas para graus decimais no pipeline', 'Helipontos privados registrados na ANAC, filtrado para os 39 municipios da RMSP: 290 registros (192 no municipio de Sao Paulo)', 'So cobre helipontos privados -- nao inclui aerodromos publicos nem Congonhas; retrato estatico datado de 11/09/2020, nao consulta em tempo real; registro de heliponto nao implica infraestrutura de vertiporto (recarga eletrica, terminal de passageiros) -- tratado como proxy de local fisicamente viavel e licenciado, decisao registrada separadamente; coordenadas informadas pelo operador no licenciamento, nao GPS independente', NULL, 'Vitor', '2026-09-14T15:24:48.465575', '89e3c4ef79a61775dee71b474b8d8e67f673c780');

-- arquivos (14 linha(s))
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (1, 'app/formulacao.md', 'Formulacao matematica completa (conjuntos, parametros, variaveis, objetivo, restricoes) do p-hub median de alocacao multipla', 4, 'Vitor', '2026-09-14T15:24:54.815257', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (2, 'app/literatura.md', 'Revisao de literatura: 7 referencias sobre modelos de localizacao de hubs e demanda de UAM', 4, 'Vitor', '2026-09-14T15:24:55.065603', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (3, 'app/data/raw/FONTES.md', 'Documentacao de origem, formato, cobertura e limitacoes dos dados brutos (OD2017, ANAC helipontos)', 2, 'Vitor', '2026-09-14T15:24:55.521140', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (4, 'app/README.md', 'Guia de reproducao do pipeline e resumo do resultado principal', 5, 'Vitor', '2026-09-14T15:24:55.809198', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (5, 'app/scripts/run_all.R', 'Script de entrada do pipeline reprodutivel de ponta a ponta', 10, 'Vitor', '2026-09-14T15:24:56.056378', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (6, 'app/data/processed/candidatos_vertiportos.csv', '8 candidatos a vertiporto (heliponto ANAC mais proximo do centroide de demanda por macrorregiao)', 6, 'Vitor', '2026-09-14T15:24:56.312430', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (7, 'app/data/processed/demanda_capturavel.csv', 'Matriz 8x8 de demanda capturavel por UAM entre macrorregioes', 7, 'Vitor', '2026-09-14T15:24:56.541732', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (8, 'app/results/figuras/curva_implantacao.png', 'Grafico da curva de implantacao: economia de tempo total vs. numero de vertiportos (p)', 8, 'Vitor', '2026-09-14T15:24:56.748421', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (9, 'app/results/tabelas/03_sensibilidade.csv', 'Tabela dos 11 cenarios de analise de sensibilidade', 7, 'Vitor', '2026-09-14T15:24:56.965166', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (10, 'app/results/tabelas/02_dual.csv', 'Precos-sombra (variaveis duais) por candidato, relaxacao linear p=4', 4, 'Vitor', '2026-09-14T15:24:57.285016', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (11, 'app/relatorio/relatorio_engenharia.md', 'Relatorio de engenharia completo (fonte Markdown): contexto, literatura, dados, modelo, tratabilidade, resultados, relaxacao/dual/sensibilidade, limitacoes, referencias', 11, 'Vitor', '2026-09-15T09:37:04.755225', '324077282fc19261f654b91819323fc6ddd6b312');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (12, 'app/relatorio/relatorio_engenharia.pdf', 'Relatorio de engenharia em PDF (entregavel formal, PDF secao 6.1), 11 paginas, com mapas e tabelas de resultado', 11, 'Vitor', '2026-09-15T09:37:04.943278', '324077282fc19261f654b91819323fc6ddd6b312');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (13, 'app/scripts/08_mapa.R', 'Script que gera o mapa esquematico da rede de vertiportos recomendada (p=4) para o relatorio', 4, 'Vitor', '2026-09-15T09:37:05.130802', '324077282fc19261f654b91819323fc6ddd6b312');
INSERT INTO arquivos (id, caminho, descricao, decisao_id, resp, criado_em, commit_hash) VALUES (14, 'app/results/figuras/mapa_rede_p4.png', 'Mapa esquematico (UTM 23S): zonas OD por macrorregiao, candidatos e rede de hubs abertos em p=4', 4, 'Vitor', '2026-09-15T09:37:05.316601', '324077282fc19261f654b91819323fc6ddd6b312');

-- referencias (7 linha(s))
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (1, 'O''Kelly, M.E. (1987). A quadratic integer program for the location of interacting hub facilities. European Journal of Operational Research, 32(3), 393-404.', 'artigo', NULL, 'Vitor', '2026-09-14T15:24:50.310751');
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (2, 'Campbell, J.F. (1994). Integer programming formulations of discrete hub location problems. European Journal of Operational Research, 72(2), 387-405.', 'artigo', NULL, 'Vitor', '2026-09-14T15:24:50.472989');
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (3, 'Alumur, S., & Kara, B.Y. (2008). Network hub location problems: The state of the art. European Journal of Operational Research, 190(1), 1-21.', 'artigo', NULL, 'Vitor', '2026-09-14T15:24:50.634767');
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (4, 'Booz Allen Hamilton / NASA (2018). Urban Air Mobility (UAM) Market Study. NASA NTRS 20190001472.', 'relatorio', 'https://ntrs.nasa.gov/citations/20190001472', 'Vitor', '2026-09-14T15:24:50.798505');
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (5, 'Rimjha, M., & Trani, A. (2021). Commuter demand estimation and feasibility assessment for Urban Air Mobility in Northern California.', 'artigo', NULL, 'Vitor', '2026-09-14T15:24:50.963010');
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (6, 'New infrastructures for Urban Air Mobility systems: A systematic review on vertiport location and capacity. Journal of Air Transport Management (2023).', 'artigo', NULL, 'Vitor', '2026-09-14T15:24:51.126545');
INSERT INTO referencias (id, citacao, tipo, url_ou_doi, resp, criado_em) VALUES (7, 'Small, K.A. (2012). Valuation of travel time. Economics of Transportation, 1(1-2), 2-14.', 'artigo', NULL, 'Vitor', '2026-09-14T15:24:51.290574');

-- experimentos (5 linha(s))
INSERT INTO experimentos (id, variante, hipotese, parametros, commit_hash, valor_objetivo, gap, tempo_solucao_s, conclusao, decisao_id, resp, criado_em) VALUES (1, 'relaxacao_linear', 'Comparar a relaxacao linear do MILP p-hub median com a solucao inteira original, para todo p testado', '{"p_range":"1..8"}', '89e3c4ef79a61775dee71b474b8d8e67f673c780', NULL, 0.0, NULL, 'Relaxacao linear e inteira (gap 0%) para todo p testado nesta instancia reduzida de 8 macrorregioes -- achado registrado sem generalizar para instancias maiores/capacitadas; ver app/results/tabelas/01_relaxacao*.csv', 4, 'Vitor', '2026-09-14T15:24:53.097384');
INSERT INTO experimentos (id, variante, hipotese, parametros, commit_hash, valor_objetivo, gap, tempo_solucao_s, conclusao, decisao_id, resp, criado_em) VALUES (2, 'dual', 'Interpretar as variaveis duais da relaxacao linear (p=4) para identificar qual recurso e escasso e quanto vale relaxa-lo', '{"p":4}', '89e3c4ef79a61775dee71b474b8d8e67f673c780', NULL, NULL, NULL, 'Dual da restricao de cardinalidade (p) = -18685.23 h-passageiro/dia por vertiporto adicional -- e o recurso mais escasso do modelo; precos-sombra por candidato em app/results/tabelas/02_dual.csv', 4, 'Vitor', '2026-09-14T15:24:53.460188');
INSERT INTO experimentos (id, variante, hipotese, parametros, commit_hash, valor_objetivo, gap, tempo_solucao_s, conclusao, decisao_id, resp, criado_em) VALUES (3, 'sensibilidade', 'A solucao (hubs abertos, economia de tempo) e sensivel as premissas de theta, velocidade de acesso, distancia minima e corte de renda assumidas pelo grupo', '{"theta":[0.02,0.05,0.10,0.15],"v_acesso_kmh":[15,20,25,30],"dist_min_km":[5,8,12],"corte_renda":["p50","p66","p80"],"n_cenarios":11}', '89e3c4ef79a61775dee71b474b8d8e67f673c780', NULL, NULL, NULL, '11 cenarios rodados; solucao e mais sensivel a theta (escala linearmente a demanda) e a velocidade de acesso terrestre (domina o tempo total, PDF 2.2) do que ao corte de renda. Tabela completa em app/results/tabelas/03_sensibilidade.csv', 7, 'Vitor', '2026-09-14T15:24:53.802885');
INSERT INTO experimentos (id, variante, hipotese, parametros, commit_hash, valor_objetivo, gap, tempo_solucao_s, conclusao, decisao_id, resp, criado_em) VALUES (4, 'curva_implantacao', 'O beneficio (economia de tempo total) em funcao do numero de vertiportos implantados (p) tem retornos marginais decrescentes, sustentando uma recomendacao de p', '{"p_range":"1..8"}', '89e3c4ef79a61775dee71b474b8d8e67f673c780', NULL, NULL, NULL, 'p=1 e infactivel por construcao (nenhum voo possivel com 1 hub). p=2 produz economia NEGATIVA (-11716.8 h-passageiro/dia, pior que nao ter UAM) -- achado honesto, rede minima forca rotas ruins. Economia so fica positiva a partir de p=3, com retorno marginal caindo monotonicamente de 42469.5 (p=3) a 1984.3 (p=8) h-passageiro/dia por vertiporto adicional. Ver app/results/figuras/curva_implantacao.png', 8, 'Vitor', '2026-09-14T15:24:53.998214');
INSERT INTO experimentos (id, variante, hipotese, parametros, commit_hash, valor_objetivo, gap, tempo_solucao_s, conclusao, decisao_id, resp, criado_em) VALUES (5, 'hub_median_p4', 'Rede de 4 vertiportos (p=4) sobre 8 macrorregioes candidatas maximiza economia de tempo porta-a-porta sob a demanda capturavel estimada', '{"p":4,"theta":0.05,"dist_min_km":8,"corte_renda":"tercio_superior","v_acesso_kmh":20,"v_cruzeiro_kmh":200,"t_overhead_min":8,"fator_sinuosidade":1.3}', '89e3c4ef79a61775dee71b474b8d8e67f673c780', 66712.46, 0.0, 0.1, 'Hubs abertos: Sao Bernardo do Campo, Guarulhos, Itaim Bibi, Jardim Paulista. Economia de tempo = 50760.2 h-passageiro/dia frente a linha de base sem UAM. Tempo de solucao real < 0.1s (lpSolve, instancia de 8 macrorregioes).', 4, 'Vitor', '2026-09-14T15:38:14.450716');

-- interacoes_ia (4 linha(s))
INSERT INTO interacoes_ia (id, proposito, pedido, resposta_resumo, aceite, critica_humana, resp, decisao_id, experimento_id, criado_em, commit_hash) VALUES (1, 'codigo', 'Implementar pipeline de dados (parser de geometria MIF, projecao UTM, agregacao de zonas) sem depender de sf/rgdal', 'Parser MIF proprio em R + projecao UTM planar fechada, k-means ponderado por viagens produzidas para agregar 517 zonas em 8 macrorregioes', 'parcial', 'O parser MIF e a conversao UTM proprios nao foram validados independentemente contra uma biblioteca de geoprocessamento de referencia (sf) nem contra coordenadas conhecidas de pontos de controle -- o erro exato introduzido pela ambiguidade de datum (SAD69 vs Corrego Alegre) e pela projecao propria nao foi quantificado, apenas estimado como ''poucos metros a dezenas de metros, irrelevante na escala de macrorregioes''. Scripts tambem nao tem testes automatizados. Vale validacao cruzada pontual antes da entrega final.', 'Vitor', 10, NULL, '2026-09-14T15:24:54.405608', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO interacoes_ia (id, proposito, pedido, resposta_resumo, aceite, critica_humana, resp, decisao_id, experimento_id, criado_em, commit_hash) VALUES (2, 'analise', 'Rodar as 4 analises obrigatorias (relaxacao, dual, sensibilidade, curva de implantacao) sobre o modelo resolvido', 'Sweep de p=1..8 para curva de implantacao; 11 cenarios de sensibilidade sobre theta/velocidade/distancia/renda; duais da relaxacao linear em p=4', 'parcial', 'Os cenarios de sensibilidade e o ponto-base (p=4, theta=5%, etc.) foram escolhidos pela propria IA sem validacao externa contra estudos independentes de dimensionamento de rede UAM em Sao Paulo -- os resultados numericos (ex.: economia de tempo em h-passageiro/dia) ainda nao foram revisados por um integrante humano do grupo nem comparados a uma ordem de grandeza de referencia externa.', 'Vitor', NULL, 3, '2026-09-14T15:24:54.627072', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO interacoes_ia (id, proposito, pedido, resposta_resumo, aceite, critica_humana, resp, decisao_id, experimento_id, criado_em, commit_hash) VALUES (3, 'formulacao', 'Escolher e justificar formulacao matematica de localizacao de vertiportos capturando interdependencia entre hubs e cadeia porta-a-porta', 'p-hub median nao-capacitado de alocacao multipla (Campbell 1994), com objetivo de minimizar tempo total porta-a-porta ponderado por demanda capturavel', 'parcial', 'O modelo forca 100% da demanda elegivel (apos filtro distancia+renda+theta) a ser roteada pela rede aerea mesmo quando, para o p disponivel, a rota otima e mais lenta que ir de carro -- achado explicito: p=2 da economia total negativa, e ha pares OD com economia individual negativa mesmo em p=4. Isso infla artificialmente a demanda ''servida''. Resolver exigiria uma opcao de nao-voar endogena no MILP (arco de ''nao captura'' com custo = alternativa terrestre), deixada como trabalho futuro documentado em app/formulacao.md secao 9. O grupo deve decidir se aceita essa simplificacao ou pede a extensao antes da entrega final.', 'Vitor', 4, 5, '2026-09-14T15:38:14.711177', '89e3c4ef79a61775dee71b474b8d8e67f673c780');
INSERT INTO interacoes_ia (id, proposito, pedido, resposta_resumo, aceite, critica_humana, resp, decisao_id, experimento_id, criado_em, commit_hash) VALUES (4, 'texto', 'Consolidar relatorio de engenharia completo (PDF secao 6.1) a partir dos artefatos ja produzidos em app/ (formulacao, dados, resultados, analises)', 'Relatorio de 11 paginas em PDF (app/relatorio/relatorio_engenharia.{md,pdf}), incluindo mapa esquematico novo e recomendacao final de p=4-6 vertiportos', 'parcial', 'O relatorio foi redigido integralmente pela IA a partir dos artefatos ja produzidos; a faixa de recomendacao final (p=4 a p=6) foi escolhida pela propria IA lendo a curva de retorno marginal, com um criterio informal (''retorno marginal abaixo de ~15-40% do primeiro salto util'') que nenhum integrante humano validou ou contestou ainda. O relatorio tambem nao foi revisado por nenhum integrante do grupo quanto a coerencia geral, erros de calculo ou concordancia com a narrativa antes desta entrega.', 'Vitor', 11, NULL, '2026-09-15T09:37:05.502528', '324077282fc19261f654b91819323fc6ddd6b312');

-- relacoes (11 linha(s))
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (1, 'decisoes', 2, 'usa', 'fontes_dados', 1, 'Vitor', '2026-09-14T15:24:57.617964');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (2, 'decisoes', 3, 'usa', 'fontes_dados', 1, 'Vitor', '2026-09-14T15:24:57.826566');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (3, 'decisoes', 6, 'usa', 'fontes_dados', 2, 'Vitor', '2026-09-14T15:24:58.003411');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (4, 'referencias', 1, 'apoia', 'decisoes', 4, 'Vitor', '2026-09-14T15:24:58.174765');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (5, 'referencias', 2, 'apoia', 'decisoes', 4, 'Vitor', '2026-09-14T15:24:58.347017');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (6, 'referencias', 3, 'apoia', 'decisoes', 4, 'Vitor', '2026-09-14T15:24:58.524861');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (7, 'referencias', 4, 'apoia', 'decisoes', 7, 'Vitor', '2026-09-14T15:24:58.705948');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (8, 'referencias', 5, 'apoia', 'decisoes', 7, 'Vitor', '2026-09-14T15:24:58.893482');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (9, 'referencias', 6, 'apoia', 'decisoes', 7, 'Vitor', '2026-09-14T15:24:59.174895');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (10, 'referencias', 7, 'apoia', 'decisoes', 7, 'Vitor', '2026-09-14T15:24:59.353891');
INSERT INTO relacoes (id, tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp, criado_em) VALUES (11, 'decisoes', 1, 'apoia', 'metas', 3, 'Vitor', '2026-09-14T17:06:14.124843');
