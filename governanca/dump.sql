-- dump.sql -- historia legivel do banco de governanca, gerada por ./gov update.
-- Fonte de verdade e governanca/projeto.duckdb; este arquivo e derivado.
-- Gerado em 2026-09-02T08:55:13.679129

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
INSERT INTO integrantes (nome, email) VALUES ('Gilberto', NULL);
INSERT INTO integrantes (nome, email) VALUES ('Guilherme', NULL);
INSERT INTO integrantes (nome, email) VALUES ('Vitor', 'biasevitor@gmail.com');
