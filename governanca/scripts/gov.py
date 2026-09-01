#!/usr/bin/env python3
"""./gov -- motor de governanca computavel do TRA-48 Projeto B1 (Camada B).

Unico caminho de escrita para governanca/projeto.duckdb. Nunca edite o banco
diretamente (ver claude.md e .claude/agents/governanca.md). Leitura rapida:
`./gov status`. Apos qualquer registro, rode `./gov update` para regenerar
dump.sql, o grafo executivo e a auditoria, e so entao comite e de push.

Fluxo: ./gov <comando> -> ./gov update -> git add -A && git commit && git push
"""

import argparse
import datetime
import json
import subprocess
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[2]
GOV_DIR = ROOT / "governanca"
DB_PATH = GOV_DIR / "projeto.duckdb"
SCHEMA_PATH = GOV_DIR / "schemas" / "schema.sql"
DUMP_PATH = GOV_DIR / "dump.sql"
DASHBOARD_DIR = GOV_DIR / "dashboard"
DOCS_DIR = ROOT / "docs"

# Ordem de dependencia (FK) usada para dump e para varredura de orfaos.
ENTITY_TABLES = [
    "integrantes", "metas", "tarefas", "pendencias", "decisoes",
    "fontes_dados", "arquivos", "referencias", "experimentos",
    "interacoes_ia", "relacoes",
]


def connect():
    con = duckdb.connect(str(DB_PATH))
    con.execute(SCHEMA_PATH.read_text())
    return con


def git_head():
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except Exception:
        return None


def valid_integrantes(con):
    return {r[0] for r in con.execute("SELECT nome FROM integrantes").fetchall()}


def require_resp(con, resp):
    nomes = valid_integrantes(con)
    if resp not in nomes:
        sys.exit(
            f"--resp '{resp}' nao esta em integrantes ({', '.join(sorted(nomes))}). "
            "Nunca registro em nome de 'o grupo' -- pergunte qual integrante e o autor."
        )


def add_common_args(p):
    p.add_argument("--resp", required=True, help="Integrante responsavel/autor deste registro")
    p.add_argument("--commit", default=None, help="Hash do commit vinculado (default: HEAD atual)")


def cmd_integrante(args):
    con = connect()
    require_resp(con, args.nome)
    con.execute("UPDATE integrantes SET email = ? WHERE nome = ?", [args.email, args.nome])
    print(f"e-mail de {args.nome} atualizado (usado em git commit --author).")


# ---------------------------------------------------------------------
# Subcomandos de registro
# ---------------------------------------------------------------------

def cmd_meta(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO metas (descricao, resp, commit_hash) VALUES (?, ?, ?) RETURNING id",
        [args.descricao, args.resp, commit],
    ).fetchall()
    print(f"meta #{row[0]} registrada.")


def cmd_tarefa(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO tarefas (descricao, resp, prazo, meta_id, commit_hash) "
        "VALUES (?, ?, ?, ?, ?) RETURNING id",
        [args.descricao, args.resp, args.prazo, args.meta, commit],
    ).fetchall()
    print(f"tarefa #{row[0]} registrada.")


def cmd_pendencia(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO pendencias (descricao, resp, meta_id, commit_hash) "
        "VALUES (?, ?, ?, ?) RETURNING id",
        [args.descricao, args.resp, args.meta, commit],
    ).fetchall()
    print(f"pendencia #{row[0]} registrada.")


def cmd_resolver_pendencia(args):
    con = connect()
    con.execute(
        "UPDATE pendencias SET resolvida_em = current_timestamp, resolucao = ? WHERE id = ?",
        [args.resolucao, args.id],
    )
    print(f"pendencia #{args.id} marcada como resolvida.")


def cmd_decisao(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO decisoes (descricao, justificativa, alternativas_descartadas, resp, meta_id, commit_hash) "
        "VALUES (?, ?, ?, ?, ?, ?) RETURNING id",
        [args.descricao, args.just, args.alt, args.resp, args.meta, commit],
    ).fetchall()
    print(f"decisao #{row[0]} registrada.")


def cmd_fonte(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO fontes_dados (nome, origem, formato, cobertura, limitacoes, credito, resp, commit_hash) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
        [args.nome, args.origem, args.formato, args.cobertura, args.limitacoes, args.credito, args.resp, commit],
    ).fetchall()
    print(f"fonte #{row[0]} registrada.")


def cmd_arquivo(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO arquivos (caminho, descricao, decisao_id, resp, commit_hash) "
        "VALUES (?, ?, ?, ?, ?) RETURNING id",
        [args.caminho, args.descricao, args.decisao, args.resp, commit],
    ).fetchall()
    print(f"arquivo #{row[0]} registrado." + ("" if args.decisao else " [sem decisao vinculada -- vira no orfao na auditoria]"))


def cmd_referencia(args):
    con = connect()
    require_resp(con, args.resp)
    (row,) = con.execute(
        "INSERT INTO referencias (citacao, tipo, url_ou_doi, resp) VALUES (?, ?, ?, ?) RETURNING id",
        [args.citacao, args.tipo, args.url, args.resp],
    ).fetchall()
    print(f"referencia #{row[0]} registrada.")


def cmd_experimento(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO experimentos (variante, hipotese, parametros, commit_hash, valor_objetivo, gap, "
        "tempo_solucao_s, conclusao, decisao_id, resp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
        [args.variante, args.hipotese, args.parametros, commit, args.obj, args.gap,
         args.tempo, args.conclusao, args.decisao, args.resp],
    ).fetchall()
    print(f"experimento #{row[0]} registrado." + ("" if args.decisao else " [sem decisao vinculada -- vira no orfao na auditoria]"))


def cmd_ia(args):
    con = connect()
    require_resp(con, args.resp)
    commit = args.commit or git_head()
    (row,) = con.execute(
        "INSERT INTO interacoes_ia (proposito, pedido, resposta_resumo, aceite, critica_humana, "
        "resp, decisao_id, experimento_id, commit_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
        [args.proposito, args.pedido, args.resposta, args.aceite, args.critica,
         args.resp, args.decisao, args.experimento, commit],
    ).fetchall()
    print(f"interacao de IA #{row[0]} registrada.")


def cmd_relacao(args):
    con = connect()
    (row,) = con.execute(
        "INSERT INTO relacoes (tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino, resp) "
        "VALUES (?, ?, ?, ?, ?, ?) RETURNING id",
        [args.origem_tipo, args.origem_id, args.tipo_relacao, args.destino_tipo, args.destino_id, args.resp],
    ).fetchall()
    print(f"relacao #{row[0]} registrada: {args.origem_tipo}:{args.origem_id} --{args.tipo_relacao}--> {args.destino_tipo}:{args.destino_id}")


# ---------------------------------------------------------------------
# status: leitura rapida sem precisar de MCP
# ---------------------------------------------------------------------

def cmd_status(_args):
    con = connect()
    for t in ENTITY_TABLES:
        if t in ("integrantes", "relacoes"):
            continue
        (n,) = con.execute(f"SELECT count(*) FROM {t}").fetchone()
        print(f"{t:16s} {n}")
    print()
    abertas = con.execute(
        "SELECT id, descricao, resp, prazo FROM tarefas WHERE status = 'aberta' ORDER BY prazo NULLS LAST"
    ).fetchall()
    print(f"tarefas abertas: {len(abertas)}")
    for r in abertas:
        print(f"  #{r[0]} [{r[2]}] {r[1]} (prazo: {r[3] or 'SEM PRAZO'})")
    pend = con.execute(
        "SELECT id, descricao, resp, criado_em FROM pendencias WHERE resolvida_em IS NULL ORDER BY criado_em"
    ).fetchall()
    print(f"\npendencias abertas: {len(pend)}")
    for r in pend:
        print(f"  #{r[0]} [{r[2]}] {r[1]} (aberta em {r[3]})")


# ---------------------------------------------------------------------
# update: regenera dump.sql, grafo executivo (JSON) e auditoria
# ---------------------------------------------------------------------

def sql_literal(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, (datetime.datetime, datetime.date)):
        return "'" + v.isoformat() + "'"
    s = str(v).replace("'", "''")
    return f"'{s}'"


def write_dump(con):
    lines = [
        "-- dump.sql -- historia legivel do banco de governanca, gerada por ./gov update.",
        "-- Fonte de verdade e governanca/projeto.duckdb; este arquivo e derivado.",
        f"-- Gerado em {datetime.datetime.now().isoformat()}",
        "",
        SCHEMA_PATH.read_text().strip(),
        "",
        "-- ==================== DADOS ====================",
    ]
    for table in ENTITY_TABLES:
        cols = [c[1] for c in con.execute(f"PRAGMA table_info('{table}')").fetchall()]
        rows = con.execute(f"SELECT {', '.join(cols)} FROM {table} ORDER BY 1").fetchall()
        if not rows:
            continue
        lines.append(f"\n-- {table} ({len(rows)} linha(s))")
        col_list = ", ".join(cols)
        for row in rows:
            vals = ", ".join(sql_literal(v) for v in row)
            lines.append(f"INSERT INTO {table} ({col_list}) VALUES ({vals});")
    DUMP_PATH.write_text("\n".join(lines) + "\n")


def build_graph(con):
    nodes = []
    edges = []

    def label_for(table, row, cols):
        d = dict(zip(cols, row))
        for k in ("descricao", "nome", "citacao", "variante", "proposito", "caminho"):
            if k in d and d[k]:
                text = str(d[k])
                return text[:80] + ("..." if len(text) > 80 else "")
        return f"{table}#{d.get('id')}"

    for table in ENTITY_TABLES:
        if table in ("integrantes", "relacoes"):
            continue
        cols = [c[1] for c in con.execute(f"PRAGMA table_info('{table}')").fetchall()]
        rows = con.execute(f"SELECT {', '.join(cols)} FROM {table}").fetchall()
        for row in rows:
            d = dict(zip(cols, row))
            node_id = f"{table}:{d['id']}"
            nodes.append({
                "id": node_id,
                "tipo": table,
                "label": label_for(table, row, cols),
                "resp": d.get("resp"),
                "criado_em": str(d.get("criado_em")) if d.get("criado_em") else None,
            })
            # arestas implicitas por FK
            if d.get("meta_id"):
                edges.append({"origem": node_id, "destino": f"metas:{d['meta_id']}", "tipo": "pertence_a"})
            if table != "decisoes" and d.get("decisao_id"):
                edges.append({"origem": node_id, "destino": f"decisoes:{d['decisao_id']}", "tipo": "vinculado_a"})
            if table == "interacoes_ia" and d.get("experimento_id"):
                edges.append({"origem": node_id, "destino": f"experimentos:{d['experimento_id']}", "tipo": "vinculado_a"})

    # arestas explicitas
    for tipo_o, id_o, rel, tipo_d, id_d in con.execute(
        "SELECT tipo_origem, id_origem, tipo_relacao, tipo_destino, id_destino FROM relacoes"
    ).fetchall():
        edges.append({"origem": f"{tipo_o}:{id_o}", "destino": f"{tipo_d}:{id_d}", "tipo": rel})

    return {"nodes": nodes, "edges": edges}


def build_auditoria(con, graph):
    total_arquivos, arquivos_vinculados = con.execute(
        "SELECT count(*), count(decisao_id) FROM arquivos"
    ).fetchone()
    total_decisoes, decisoes_vinculadas = con.execute(
        "SELECT count(*), count(meta_id) FROM decisoes"
    ).fetchone()
    total_experimentos, experimentos_vinculados = con.execute(
        "SELECT count(*), count(decisao_id) FROM experimentos"
    ).fetchone()

    linked_ids = {e["origem"] for e in graph["edges"]} | {e["destino"] for e in graph["edges"]}
    orfaos = [n["id"] for n in graph["nodes"] if n["tipo"] in ("arquivos", "decisoes", "experimentos") and n["id"] not in linked_ids]

    pendencias_antigas = con.execute(
        "SELECT id, descricao, resp, criado_em FROM pendencias "
        "WHERE resolvida_em IS NULL AND criado_em < current_timestamp - INTERVAL 14 DAY"
    ).fetchall()
    tarefas_sem_prazo = con.execute(
        "SELECT id, descricao, resp FROM tarefas WHERE prazo IS NULL AND status = 'aberta'"
    ).fetchall()

    cadencia = con.execute(
        "SELECT strftime(criado_em, '%Y-W%W') AS semana, count(*) FROM ("
        "  SELECT criado_em FROM decisoes"
        "  UNION ALL SELECT criado_em FROM experimentos"
        "  UNION ALL SELECT criado_em FROM interacoes_ia"
        ") GROUP BY semana ORDER BY semana"
    ).fetchall()

    ia_dist = con.execute(
        "SELECT aceite, count(*) FROM interacoes_ia GROUP BY aceite"
    ).fetchall()
    total_ia = sum(n for _, n in ia_dist) or 0
    integral = dict(ia_dist).get("integral", 0)
    taxa_aceite_integral = (integral / total_ia) if total_ia else None

    return {
        "gerado_em": datetime.datetime.now().isoformat(),
        "rastreabilidade": {
            "pct_arquivos_vinculados_a_decisao": (arquivos_vinculados / total_arquivos) if total_arquivos else None,
            "pct_decisoes_vinculadas_a_meta": (decisoes_vinculadas / total_decisoes) if total_decisoes else None,
            "pct_experimentos_vinculados_a_decisao": (experimentos_vinculados / total_experimentos) if total_experimentos else None,
            "nos_orfaos": orfaos,
        },
        "cadencia_por_semana": [{"semana": s, "registros": n} for s, n in cadencia],
        "higiene": {
            "pendencias_abertas_ha_mais_de_14_dias": [
                {"id": r[0], "descricao": r[1], "resp": r[2], "criado_em": str(r[3])} for r in pendencias_antigas
            ],
            "tarefas_sem_prazo": [{"id": r[0], "descricao": r[1], "resp": r[2]} for r in tarefas_sem_prazo],
        },
        "postura_critica_ia": {
            "distribuicao": {k: v for k, v in ia_dist},
            "taxa_aceite_integral": taxa_aceite_integral,
            "alerta_aceite_alto": bool(taxa_aceite_integral and taxa_aceite_integral >= 0.8 and total_ia >= 5),
        },
    }


DASHBOARD_TEMPLATE = """<!doctype html>
<html lang="pt-br">
<head>
<meta charset="utf-8">
<title>TRA-48 -- Grafo executivo</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, Segoe UI, sans-serif; margin: 0; padding: 2rem; max-width: 1100px; margin-inline: auto; line-height: 1.5; }
  h1 { margin-bottom: 0; }
  .sub { color: #888; margin-top: .25rem; }
  .selo { display: inline-block; padding: .25rem .6rem; border-radius: .4rem; font-weight: 600; font-size: .85rem; }
  .selo.ok { background: #1a7f3722; color: #1a7f37; }
  .selo.alerta { background: #cf222e22; color: #cf222e; }
  section { margin-top: 2.5rem; }
  table { width: 100%; border-collapse: collapse; font-size: .9rem; }
  th, td { text-align: left; padding: .4rem .5rem; border-bottom: 1px solid #8883; vertical-align: top; }
  th { color: #888; font-weight: 600; }
  code { background: #8882; padding: .1rem .3rem; border-radius: .3rem; }
  .grafo-col { display: inline-block; vertical-align: top; width: 11%; margin-right: .5%; }
  .grafo-col h4 { font-size: .75rem; text-transform: uppercase; color: #888; margin: 0 0 .4rem; }
  .no { font-size: .72rem; padding: .3rem; margin-bottom: .3rem; border-radius: .3rem; background: #8882; }
  svg { width: 100%; height: auto; }
  .metric { display: inline-block; margin-right: 2rem; }
  .metric b { font-size: 1.4rem; display: block; }
  .orfao { color: #cf222e; }
</style>
</head>
<body>
<h1>TRA-48 -- Grafo executivo</h1>
<p class="sub">Localizacao de vertiportos em Sao Paulo -- Camada B (governanca). Gerado por <code>./gov update</code> em __GERADO_EM__.</p>

<section>
<h2>Estado</h2>
__ESTADO__
</section>

<section>
<h2>Grafo executivo</h2>
<p class="sub">Nos por tipo; arestas ligam decisoes, fontes, arquivos, experimentos e interacoes de IA as metas do projeto.</p>
__GRAFO__
</section>

<section>
<h2>Tarefas e pendencias</h2>
__TAREFAS__
</section>

<section>
<h2>Decisoes</h2>
__DECISOES__
</section>

<section>
<h2>Experimentos</h2>
__EXPERIMENTOS__
</section>

<section>
<h2>Interacoes com IA</h2>
__IA__
</section>
</body>
</html>
"""


def render_dashboard(con, graph, auditoria):
    orfaos = auditoria["rastreabilidade"]["nos_orfaos"]
    selo = '<span class="selo alerta">auditoria: pendencias encontradas</span>' if orfaos or auditoria["postura_critica_ia"]["alerta_aceite_alto"] \
        else '<span class="selo ok">auditoria: sem pendencias</span>'

    def pct(x):
        return "n/d" if x is None else f"{x*100:.0f}%"

    estado = f"""
    <p>{selo}</p>
    <div class="metric"><b>{pct(auditoria['rastreabilidade']['pct_decisoes_vinculadas_a_meta'])}</b>decisoes com meta</div>
    <div class="metric"><b>{pct(auditoria['rastreabilidade']['pct_arquivos_vinculados_a_decisao'])}</b>arquivos com decisao</div>
    <div class="metric"><b>{pct(auditoria['rastreabilidade']['pct_experimentos_vinculados_a_decisao'])}</b>experimentos com decisao</div>
    <div class="metric"><b>{len(orfaos)}</b>nos orfaos</div>
    """
    if orfaos:
        estado += "<p class='orfao'>Orfaos: " + ", ".join(orfaos) + "</p>"

    tipos = ["metas", "decisoes", "fontes_dados", "arquivos", "experimentos", "interacoes_ia", "tarefas", "pendencias", "referencias"]
    id_pos = {}
    cols_html = []
    for i, tipo in enumerate(tipos):
        nos = [n for n in graph["nodes"] if n["tipo"] == tipo]
        col = [f"<div class='grafo-col'><h4>{tipo} ({len(nos)})</h4>"]
        for j, n in enumerate(nos):
            id_pos[n["id"]] = (i, j)
            col.append(f"<div class='no' title='{n['resp'] or ''}'>{n['label']}</div>")
        col.append("</div>")
        cols_html.append("".join(col))
    grafo_html = "".join(cols_html)
    grafo_html += f"<p class='sub'>{len(graph['edges'])} relacao(oes) no grafo (ver grafo.json para a estrutura completa, incluindo arestas).</p>"

    def table(headers, rows):
        if not rows:
            return "<p class='sub'>Nenhum registro ainda.</p>"
        head = "".join(f"<th>{h}</th>" for h in headers)
        body = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
        return f"<table><tr>{head}</tr>{body}</table>"

    tarefas = con.execute("SELECT id, descricao, resp, prazo, status FROM tarefas ORDER BY prazo NULLS LAST").fetchall()
    pendencias = con.execute("SELECT id, descricao, resp, criado_em, resolvida_em FROM pendencias ORDER BY criado_em").fetchall()
    tarefas_html = table(["#", "descricao", "resp", "prazo", "status"], tarefas)
    tarefas_html += "<h3>Pendencias</h3>" + table(["#", "descricao", "resp", "aberta em", "resolvida em"], pendencias)

    decisoes = con.execute(
        "SELECT id, descricao, justificativa, alternativas_descartadas, resp, criado_em FROM decisoes ORDER BY criado_em"
    ).fetchall()
    decisoes_html = table(["#", "descricao", "justificativa", "alternativas descartadas", "resp", "quando"], decisoes)

    experimentos = con.execute(
        "SELECT id, variante, hipotese, valor_objetivo, gap, tempo_solucao_s, conclusao, resp FROM experimentos ORDER BY criado_em"
    ).fetchall()
    experimentos_html = table(["#", "variante", "hipotese", "FO", "gap", "tempo (s)", "conclusao", "resp"], experimentos)

    ia = con.execute(
        "SELECT id, proposito, aceite, critica_humana, resp, criado_em FROM interacoes_ia ORDER BY criado_em"
    ).fetchall()
    dist = auditoria["postura_critica_ia"]["distribuicao"]
    ia_html = f"<p>Distribuicao de aceite: {dist}</p>" + table(["#", "proposito", "aceite", "critica humana", "resp", "quando"], ia)

    html = DASHBOARD_TEMPLATE
    html = html.replace("__GERADO_EM__", auditoria["gerado_em"])
    html = html.replace("__ESTADO__", estado)
    html = html.replace("__GRAFO__", grafo_html)
    html = html.replace("__TAREFAS__", tarefas_html)
    html = html.replace("__DECISOES__", decisoes_html)
    html = html.replace("__EXPERIMENTOS__", experimentos_html)
    html = html.replace("__IA__", ia_html)
    return html


def cmd_update(_args):
    con = connect()
    write_dump(con)
    graph = build_graph(con)
    auditoria = build_auditoria(con, graph)

    DASHBOARD_DIR.mkdir(parents=True, exist_ok=True)
    (DASHBOARD_DIR / "grafo.json").write_text(json.dumps(graph, indent=2, ensure_ascii=False))
    (DASHBOARD_DIR / "auditoria.json").write_text(json.dumps(auditoria, indent=2, ensure_ascii=False))

    html = render_dashboard(con, graph, auditoria)
    (DASHBOARD_DIR / "index.html").write_text(html)

    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    (DOCS_DIR / "index.html").write_text(html)
    (DOCS_DIR / "grafo.json").write_text(json.dumps(graph, indent=2, ensure_ascii=False))
    (DOCS_DIR / "auditoria.json").write_text(json.dumps(auditoria, indent=2, ensure_ascii=False))

    print(f"dump.sql, grafo.json, auditoria.json e o painel foram regenerados.")
    if auditoria["rastreabilidade"]["nos_orfaos"]:
        print(f"ALERTA: {len(auditoria['rastreabilidade']['nos_orfaos'])} no(s) orfao(s): "
              + ", ".join(auditoria["rastreabilidade"]["nos_orfaos"]))
    if auditoria["postura_critica_ia"]["alerta_aceite_alto"]:
        print("ALERTA: taxa de aceite integral de IA >= 80% -- sinal de ausencia de revisao critica.")
    for p in auditoria["higiene"]["pendencias_abertas_ha_mais_de_14_dias"]:
        print(f"ALERTA: pendencia #{p['id']} aberta ha mais de 14 dias (resp: {p['resp']}).")


# ---------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------

def build_parser():
    p = argparse.ArgumentParser(prog="gov", description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("meta", help="Registrar uma meta do projeto")
    sp.add_argument("descricao")
    add_common_args(sp)
    sp.set_defaults(func=cmd_meta)

    sp = sub.add_parser("tarefa", help="Registrar uma tarefa")
    sp.add_argument("descricao")
    sp.add_argument("--prazo", help="YYYY-MM-DD")
    sp.add_argument("--meta", type=int, help="id da meta vinculada")
    add_common_args(sp)
    sp.set_defaults(func=cmd_tarefa)

    sp = sub.add_parser("pendencia", help="Registrar uma pendencia")
    sp.add_argument("descricao")
    sp.add_argument("--meta", type=int)
    add_common_args(sp)
    sp.set_defaults(func=cmd_pendencia)

    sp = sub.add_parser("resolver-pendencia", help="Marcar uma pendencia como resolvida")
    sp.add_argument("id", type=int)
    sp.add_argument("--resolucao", required=True)
    sp.set_defaults(func=cmd_resolver_pendencia)

    sp = sub.add_parser("decisao", help="Registrar uma decisao metodologica")
    sp.add_argument("descricao")
    sp.add_argument("--just", required=True, help="Justificativa da escolha")
    sp.add_argument("--alt", required=True, help="Alternativas descartadas")
    sp.add_argument("--meta", type=int)
    add_common_args(sp)
    sp.set_defaults(func=cmd_decisao)

    sp = sub.add_parser("fonte", help="Registrar uma fonte de dados")
    sp.add_argument("nome")
    sp.add_argument("--origem", required=True)
    sp.add_argument("--formato")
    sp.add_argument("--cobertura")
    sp.add_argument("--limitacoes", required=True)
    sp.add_argument("--credito", help="Credito, se a fonte veio de outro grupo (2.6)")
    add_common_args(sp)
    sp.set_defaults(func=cmd_fonte)

    sp = sub.add_parser("arquivo", help="Registrar um arquivo (script, mapa, base derivada, relatorio)")
    sp.add_argument("caminho")
    sp.add_argument("--descricao")
    sp.add_argument("--decisao", type=int, help="id da decisao que este arquivo implementa/deriva")
    add_common_args(sp)
    sp.set_defaults(func=cmd_arquivo)

    sp = sub.add_parser("referencia", help="Registrar uma referencia bibliografica")
    sp.add_argument("citacao")
    sp.add_argument("--tipo")
    sp.add_argument("--url")
    sp.add_argument("--resp", required=True)
    sp.set_defaults(func=cmd_referencia)

    sp = sub.add_parser("experimento", help="Registrar uma rodada do modelo")
    sp.add_argument("--variante", required=True)
    sp.add_argument("--hipotese", required=True)
    sp.add_argument("--parametros", help="JSON livre, ex: '{\"p\": 8}'")
    sp.add_argument("--obj", type=float, dest="obj")
    sp.add_argument("--gap", type=float)
    sp.add_argument("--tempo", type=float, dest="tempo")
    sp.add_argument("--conclusao")
    sp.add_argument("--decisao", type=int)
    add_common_args(sp)
    sp.set_defaults(func=cmd_experimento)

    sp = sub.add_parser("ia", help="Registrar uma interacao com IA (critica humana obrigatoria)")
    sp.add_argument("--proposito", required=True, help="formulacao | codigo | analise | texto | ...")
    sp.add_argument("--pedido")
    sp.add_argument("--resposta")
    sp.add_argument("--aceito", "--aceite", dest="aceite", required=True, choices=["integral", "parcial", "descarte"])
    sp.add_argument("--critica", required=True, help="O que estava errado, incompleto ou discutivel")
    sp.add_argument("--decisao", type=int)
    sp.add_argument("--experimento", type=int)
    add_common_args(sp)
    sp.set_defaults(func=cmd_ia)

    sp = sub.add_parser("relacao", help="Ligar dois nos quaisquer do grafo executivo")
    sp.add_argument("--origem-tipo", required=True, choices=["metas", "tarefas", "pendencias", "decisoes", "fontes_dados", "arquivos", "referencias", "experimentos", "interacoes_ia"])
    sp.add_argument("--origem-id", required=True, type=int)
    sp.add_argument("--tipo-relacao", required=True, help="ex: usa, produz, apoia, credita")
    sp.add_argument("--destino-tipo", required=True, choices=["metas", "tarefas", "pendencias", "decisoes", "fontes_dados", "arquivos", "referencias", "experimentos", "interacoes_ia"])
    sp.add_argument("--destino-id", required=True, type=int)
    sp.add_argument("--resp")
    sp.set_defaults(func=cmd_relacao)

    sp = sub.add_parser("integrante", help="Atualizar o e-mail de um integrante (usado em git commit --author)")
    sp.add_argument("nome")
    sp.add_argument("--email", required=True)
    sp.set_defaults(func=cmd_integrante)

    sp = sub.add_parser("status", help="Ler o estado atual do banco")
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("update", help="Regenerar dump.sql, grafo executivo e auditoria")
    sp.set_defaults(func=cmd_update)

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
