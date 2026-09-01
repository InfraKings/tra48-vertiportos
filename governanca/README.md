# governanca/

Banco de governanca computavel do TRA-48 Projeto B1 (Camada B), conforme
`Projeto_TRA48.pdf` cap. 5. `projeto.duckdb` e a fonte de verdade; tudo
neste diretorio, exceto `schemas/` e `scripts/`, e derivado dele.

```
projeto.duckdb   fonte de verdade (DuckDB)
dump.sql         historico legivel, gerado por `./gov update`
schemas/         esquema do banco (schema.sql) -- as entidades do grafo executivo
scripts/         gov.py -- unico caminho de escrita
dashboard/       painel gerado (index.html, grafo.json, auditoria.json)
```

## Regra fundamental

Escrita **sempre** via `./gov` (na raiz do repositorio). Nunca editar
`projeto.duckdb` diretamente. Decisao sem registro no banco nao aconteceu.

## Uso

```
./gov meta "..." --resp <Vitor|Gilberto|Guilherme>
./gov tarefa "..." --resp Ana --prazo 2026-09-02 --meta 1
./gov decisao "..." --just "..." --alt "..." --resp Vitor --meta 1
./gov pendencia "..." --resp Vitor
./gov fonte "..." --origem ... --limitacoes ... --resp Vitor
./gov arquivo caminho/do/arquivo --decisao 1 --resp Vitor
./gov referencia "..." --resp Vitor
./gov experimento --variante cobertura --hipotese "..." --obj 12345 --decisao 1 --resp Vitor
./gov ia --proposito formulacao --aceito parcial --critica "..." --resp Vitor
./gov relacao --origem-tipo decisoes --origem-id 1 --tipo-relacao usa --destino-tipo fontes_dados --destino-id 1

./gov status   # leitura rapida do estado atual
./gov update   # regenera dump.sql, grafo.json e auditoria.json; SEMPRE antes de comitar
```

Fluxo completo: `./gov <comando>` -> `./gov update` -> `git add -A && git
commit --author="Nome <email>" && git push`.

`./gov update` também imprime alertas de auditoria (nós órfãos, taxa de
aceite de IA >= 80%, pendências abertas há mais de 14 dias) -- os mesmos
que ficam gravados em `dashboard/auditoria.json` e espelhados em `docs/`
para o GitHub Pages.

## O que ainda falta (fora do escopo desta rodada)

- Preencher os e-mails dos integrantes em `integrantes` (necessario para
  `git commit --author`).
- Servidor MCP para leitura do banco direto do assistente de IA (5.8 cita
  isso como leitura alternativa; escrita continua sempre via `./gov`).
- Habilitar GitHub Pages nas configuracoes do repositorio (Settings ->
  Pages -> Source: GitHub Actions) para que `.github/workflows/governanca.yml`
  publique `docs/` automaticamente.
