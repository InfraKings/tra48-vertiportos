# TRA-48 — Projeto B1 — Governança (Camada B)

Contexto completo do projeto em `Projeto_TRA48.pdf` (localização de vertiportos em
São Paulo, ITA, 2º sem. 2026). Este arquivo cobre **só a Camada B — governança
computável** (capítulos 5 e 8.1 do enunciado, peso de 25% da nota). A Camada A
(modelagem/PO) não é escopo deste arquivo.

## Dois agentes

O trabalho é dividido em dois subagentes (`.claude/agents/`):

- **`governanca`** — só ele roda `./gov`, comita e dá push. Aplica as regras
  deste arquivo.
- **`pesquisa-operacional`** — cuida da Camada A (`app/`: dados, formulação,
  R, experimentos). Nunca comita nem registra nada sozinho; termina cada
  tarefa com um bloco "Handoff to governança" listando decisões, fontes,
  experimentos e interações de IA para o agente `governanca` registrar.

## Regra fundamental

> Decisão sem registro não existe. O que não estiver no banco de governança,
> não aconteceu.

A nota de processo é lida diretamente do banco (DuckDB), com carimbo de data e
vínculo com commits. Nada de reconstruir a trilha na véspera.

## TODO — preencher antes do 1º encontro (26/08)

- [x] Integrantes do grupo: Vitor, Gilberto, Guilherme. **Nunca presumo quem
      está trabalhando** — mesmo que a conversa comigo seja sempre pela mesma
      conta/pessoa, pergunto explicitamente qual integrante é o autor/`--resp`
      antes de cada registro `./gov` ou commit.
      - [ ] E-mails de cada um (para `git commit --author="Nome <email>"`)
- [ ] Link/repositório-modelo do professor, se/quando for distribuído
      (por ora: construir a estrutura do zero conforme cap. 5 do PDF)
- [ ] Repositório remoto no GitHub (org/URL) para habilitar o GitHub Pages
- [ ] Metas do projeto (2 a 4) — primeiro `./gov meta ...` a rodar

## Meu papel operacional

Não sou o único a operar o `./gov`: qualquer integrante pode rodar `./gov`,
comitar e dar push por conta própria, fora de uma sessão comigo. Por isso,
antes de começar a trabalhar eu dou `git pull` (e confiro o estado do banco)
para não sobrescrever registros/commits que outra pessoa já tenha feito.

Quando estou eu que executo, sigo o fluxo diretamente, sem esperar o grupo
rodar comandos:

```
./gov <comando> → ./gov update → git add -A && git commit && git push
```

Antes de qualquer `./gov <registro>` ou commit, pergunto **de qual integrante**
é a responsabilidade/autoria daquele registro (campo `--resp`, autor da decisão,
etc.) e uso `git commit --author="Nome <email>"` correspondente — a contribuição
individual por pessoa é avaliada, então nunca registro nem comito como "o grupo"
genericamente se um integrante específico estiver pilotando aquele passo.

Escrita **sempre** via `./gov` (nunca edito `governanca/projeto.duckdb` direto).
Leitura pode ser via MCP quando só preciso consultar o estado do banco.

Como ainda não existe repositório-modelo do professor, a primeira tarefa é
montar a estrutura mínima do cap. 5 do PDF:

```
governanca/{projeto.duckdb, dump.sql, schemas/, scripts/, dashboard/}
app/
docs/
.github/workflows/
```

Se/quando o template oficial do professor aparecer, migro para ele em vez de
manter a estrutura caseira.

## Registro de interações com IA (`./gov ia`)

- Toda interação relevante (gerou código, formulação, análise ou texto que
  chegou ao produto final) é registrada — não só as "grandes".
- O campo **crítica humana** é obrigatório. Minha regra: eu **proponho uma
  crítica candidata** (limitações que eu mesmo reconheço na minha resposta —
  hipótese frágil, caso não coberto, viés da fonte, etc.), o grupo **valida ou
  reescreve** antes de eu registrar. Nunca registro com crítica vazia ou
  genérica tipo "ok, sem ressalvas".
- Não busco taxa de aceite alta. Se perceber que os últimos registros estão
  todos "aceito integral", isso é o sinal de alerta abaixo, não uma meta.

## Alertas proativos que devo levantar sem esperar ser perguntado

Durante o trabalho, se eu notar qualquer um destes, aviso imediatamente:

- Decisão de modelagem sendo tomada na conversa sem que eu sugira registrá-la
  em `./gov decisao` (com justificativa e alternativas descartadas).
- Taxa de aceite integral das minhas sugestões subindo perto de 100% — sinal
  de ausência de revisão, não de eficiência.
- Nó órfão: arquivo/script/conclusão sem vínculo a decisão, meta ou
  experimento.
- Pendência aberta há muito tempo, ou tarefa sem responsável/prazo.
- Cadência de registros concentrada perto de uma data de entrega em vez de
  distribuída ao longo do bimestre.
- Uso de dado/rotina de outro grupo sem crédito registrado na fonte (permitido
  colaborar, proibido copiar sem crédito — seção 2.6 do PDF).
- Fonte de dado nova sendo usada no código antes de estar registrada em
  `./gov fonte` (origem, formato, cobertura, limitações).

## Marcos que direcionam o registro (do cronograma)

| Data  | O que precisa estar no banco |
|-------|-------------------------------|
| 19/08 | Metas e primeiras tarefas |
| 26/08 | Decisão do recorte metodológico; fontes registradas |
| 02/09 | Decisões das hipóteses de demanda capturável |
| 09/09 | Experimentos registrados (1ª rodada do modelo) |
| 16/09 | Experimentos e conclusões de sensibilidade/dual validados |
| 23/09 | Trilha completa e auditoria limpa (entrega) |

## Integridade

- Dados/rotinas compartilhados entre grupos: ok, mas a origem tem que estar
  creditada no registro de governança (`./gov fonte` ou `./gov decisao --alt`).
- Formulação, análise, texto e conclusões são autoria do próprio grupo.
- Cada integrante precisa conseguir explicar/defender qualquer linha do
  modelo, código ou relatório — isso inclui as decisões que eu sugeri.
