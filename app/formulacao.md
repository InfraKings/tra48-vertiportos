# Formulação matemática — localização de vertiportos na RMSP

Projeto B1, TRA-48 (ITA). Este documento define o modelo de Programação
Linear Inteira Mista (MILP) usado para decidir onde abrir vertiportos na
Região Metropolitana de São Paulo (RMSP), sob a hipótese de demanda
capturável descrita em `app/data/processed/demanda_capturavel.csv` (ver
`app/scripts/05_demanda.R`).

## 1. Por que hub location, e não cobertura ou p-mediana clássica

O enunciado (`Projeto_TRA48.pdf`, §2.2) exige que o modelo trate a viagem
como uma cadeia porta-a-porta:

```
origem → [acesso terrestre] → vertiporto k → [voo] → vertiporto l → [egresso] → destino
```

e que capture que **o valor de abrir o vertiporto k depende de quais outros
vertiportos l estão abertos** — não é ranking por demanda nem cobertura de
raio fixo. Isso descarta:

- **Location Set Covering / Maximal Covering**: cobrem pontos de demanda
  dentro de um raio, mas não modelam o trecho aéreo hub-a-hub nem a
  interdependência entre pares de vertiportos.
- **p-mediana clássica (1 facility por cliente, sem trecho intermediário)**:
  minimiza distância cliente-facility, mas não representa o segundo trecho
  (o voo até outro vertiporto) nem o fato de que uma viagem só é servida se
  **ambas as pontas** (origem e destino) tiverem vertiporto aberto.

O que resta é a família de **hub location problems** (O'Kelly, 1987;
Campbell, 1994; Alumur & Kara, 2008 — ver `app/literatura.md`), desenhada
exatamente para decidir simultaneamente (i) quais nós viram hub e (ii) como
alocar cada par origem-destino a um par de hubs, com o custo de servir cada
par de OD dependendo da rede completa de hubs abertos, não de uma decisão
isolada. Adotamos a variante de **alocação múltipla** (cada par OD pode, em
princípio, ser roteado por qualquer par de hubs abertos, e a otimização
escolhe o melhor), porque ela admite uma formulação **linear** (sem produtos
bilineares de variáveis 0/1), resolvível com `lpSolve` — a formulação
clássica de alocação única de O'Kelly (1987) é quadrática e exigiria um
solver de MIQP que não está disponível nesta sessão (decisão registrada, ver
handoff).

## 2. Conjuntos

| Conjunto | Definição | Cardinalidade |
|---|---|---|
| `Z` | Macrorregiões da RMSP, obtidas agregando as 517 zonas da Pesquisa OD 2017 por k-means ponderado por viagens produzidas (`app/scripts/02_macrorregioes.R`) | \|Z\| = 8 |
| `K`, `L` | Candidatos a vertiporto — **mesmo índice que `Z`**: um candidato por macrorregião, o heliponto ANAC mais próximo do centroide de demanda da região (`app/scripts/03_candidatos.R`) | \|K\|=\|L\|=8 |

`Z` faz dupla função (zona de demanda **e** universo de candidatos) — decisão
de redução de instância explicada na Seção 6, não uma coincidência de
modelagem.

Índices: `i, j ∈ Z` (origem, destino da viagem porta-a-porta); `k, l ∈ K`
(vertiporto de embarque, vertiporto de desembarque), com `k ≠ l` (um voo
liga sempre dois vertiportos distintos — não existe "voo" de um vertiporto
para ele mesmo).

## 3. Parâmetros

| Símbolo | Significado | Unidade | Procedência |
|---|---|---|---|
| `W_ij` | Demanda diária capturável por UAM, região `i` → região `j` | viagens/dia | Pesquisa OD 2017 (Tabela 25, viagens por transporte individual motorizado), agregada por macrorregião e filtrada por elegibilidade de distância + renda + fração comportamental `θ` — ver §4 e `app/scripts/05_demanda.R` |
| `t^acesso_ik` | Tempo de acesso terrestre do centroide de `i` até o vertiporto `k` | h | `fator_sinuosidade × dist_UTM(i,k) / v_acesso`, distância calculada a partir dos centroides UTM das zonas (`app/scripts/00_utils.R`) |
| `t^voo_kl` | Tempo de voo `k → l` | h | `dist_UTM(k,l) / v_cruzeiro + t_overhead` |
| `t^egresso_lj` | Tempo de egresso terrestre de `l` até o centroide de `j` | h | mesma fórmula de `t^acesso`, com `(l,j)` |
| `t0_ij` | Tempo de viagem terrestre direta `i → j` (linha de base, sem UAM) | h | `fator_sinuosidade × dist_UTM(i,j) / v_acesso` |
| `v_acesso` | Velocidade média de acesso/egresso terrestre | km/h | assumido = 20 km/h (ordem de grandeza de via arterial congestionada em pico na RMSP; ver `app/scripts/04_parametros.R` e análise de sensibilidade) |
| `v_cruzeiro` | Velocidade de cruzeiro do eVTOL | km/h | 200 km/h, Eve (Embraer), única fabricante em processo de certificação ANAC — ver `app/literatura.md` |
| `t_overhead` | Tempo fixo de embarque/segurança/taxi por voo | h | 8 min, ordem de grandeza do turnaround citado pela Archer para operação urbana |
| `fator_sinuosidade` | Razão distância real / distância em linha reta no trecho terrestre | adimensional | 1,3, valor usual em estudos de transporte urbano |
| `θ` | Fração comportamental de adesão dentre os pares OD elegíveis | adimensional | 0,05 (base), 0,02–0,15 na sensibilidade — NASA/Booz Allen Hamilton (2018), Rimjha & Trani (2021) |
| `p` | Número de vertiportos a implantar | inteiro | parâmetro variado de 1 a 8 (curva de implantação) |

Todos os parâmetros assumidos (não vindos diretamente do dado OD) estão
centralizados em `app/scripts/04_parametros.R`, com a justificativa de cada
valor no comentário do código — nenhum "número mágico" solto nos scripts de
modelagem.

## 4. Variáveis de decisão

- `h_k ∈ {0,1}` — 1 se o vertiporto candidato `k` é aberto. É a variável que
  operacionaliza "onde e quantos vertiportos implantar" (§2.3 do enunciado).
- `x_ijkl ∈ [0,1]`, contínua, para `k ≠ l` e todo par `(i,j)` com `W_ij>0` —
  fração da demanda `W_ij` roteada via embarque em `k` e desembarque em `l`.
  Não é preciso declarar `x_ijkl` binária: numa alocação múltipla sem
  restrição de capacidade, o ótimo da relaxação contínua já é 0/1 sempre que
  há um único par `(k,l)` estritamente mais barato para aquele par OD — o
  que é o caso típico aqui (ver §7, relaxação linear). Isso é o que torna o
  problema resolvível por `lpSolve` num MILP com só 8 variáveis binárias.

## 5. Função objetivo

Minimizar o tempo total de viagem generalizado da demanda capturada,
somado sobre todos os pares OD servidos pela rede de vertiportos:

```
min  Σ_{(i,j): W_ij>0} Σ_{k≠l} W_ij · x_ijkl · (t^acesso_ik + t^voo_kl + t^egresso_lj)
```

**Por que este critério e não outro.** O enunciado (§2.3) lista minimizar
tempo total, maximizar demanda capturada, maximizar economia de tempo ou
minimizar custo de implantação como critérios legítimos. Escolhemos
minimizar tempo total generalizado porque:

1. É o critério com interpretação de dual mais direta e pedagogicamente
   alinhada ao vínculo com Programação Linear exigido no §4.4 — os preços-
   sombra das restrições de alocação (2)-(3) abaixo têm unidade de
   "horas-passageiro por vaga de hub", diretamente interpretável.
2. Maximizar economia de tempo (`Σ W_ij·(t0_ij − t_uam_ij)`) é
   matematicamente equivalente a este objetivo a menos de uma constante
   (`Σ W_ij·t0_ij`, que não depende das variáveis de decisão) — calculamos
   a economia de tempo como **métrica derivada** pós-solução (ver
   `app/scripts/07_experimentos.R`), sem precisar de um segundo modelo.
3. Minimizar custo de implantação exigiria um parâmetro de custo fixo por
   vertiporto (`c_k`) para o qual não encontramos fonte pública confiável
   dentro do prazo desta sessão (infraestrutura de vertiporto eVTOL é uma
   tecnologia nova, sem histórico de custos publicado no Brasil) — decisão
   registrada de **não** incluir custo fixo endógeno, tratando `p` como
   parâmetro exógeno variado na curva de implantação (§8) em vez de
   endogenizar via `Σ c_k h_k` no objetivo. Isto é uma limitação assumida
   explicitamente, não um esquecimento.

## 6. Restrições

```
(1) Σ_{k≠l} x_ijkl = 1                  ∀ (i,j): W_ij > 0
(2) Σ_{l≠k} x_ijkl ≤ h_k                ∀ (i,j): W_ij > 0,  ∀ k ∈ K
(3) Σ_{k≠l} x_ijkl ≤ h_l                ∀ (i,j): W_ij > 0,  ∀ l ∈ L
(4) Σ_k h_k = p
(5) x_ijkl ≥ 0 ;  h_k ∈ {0,1}
```

- **(1)** — toda a demanda capturada é roteada por algum par de vertiportos
  (não sobra demanda "no limbo"); é o que torna o problema um *p-hub
  median* e não um problema de cobertura parcial.
- **(2) e (3)** — uma rota só pode usar um vertiporto se ele estiver aberto.
  Esta é a restrição que gera a **interdependência exigida pelo enunciado**:
  o par `(i,j)` só consegue uma rota barata se **tanto** `k` quanto `l`
  estiverem abertos; abrir só `k` sem abrir nenhum `l` complementar não
  serve ninguém. É a tradução matemática direta de "o valor de abrir o
  vertiporto k depende de quais outros vertiportos l estão abertos" e de
  "existe massa crítica" (§2.2, itens 2 e 3 do enunciado).
- **(4)** — fixa o número de vertiportos implantados em `p`; variada de 1 a
  8 para construir a curva de implantação (análise obrigatória #4, §4.4).
- **(5)** — domínio das variáveis.

## 7. O que o modelo NÃO captura, e por quê isso é aceitável (por ora)

Seguindo a exigência do enunciado (§4.3) de honestidade sobre omissões:

- **Capacidade dos vertiportos**: o modelo é *uncapacitated* — não há limite
  de pousos/decolagens por vertiporto. Aceitável porque a demanda capturada
  já é uma fração pequena (θ=5%) da demanda motorizada individual total, e
  o objetivo desta primeira camada é a localização, não o dimensionamento
  operacional; fica como extensão natural (restrição `Σ_ij Σ_l x_ijkl·W_ij
  ≤ Cap_k` por hub) registrada como trabalho futuro.
- **Custo de implantação/operação**: ver §5, item 3 — não há dado de custo
  confiável para eVTOL no Brasil nesta janela de tempo; `p` é exógeno.
- **Autonomia/alcance da aeronave**: não impomos `t^voo_kl` máximo. Checamos
  a posteriori (`app/scripts/06_modelo_hub.R`) que a maior distância
  candidato-candidato fica bem abaixo do alcance citado da Eve (~100 km) —
  não é uma restrição ativa na escala da RMSP, então omiti-la não distorce
  o resultado, mas isso só vale para este recorte geográfico.
- **Elasticidade de tarifa/renda**: `θ` é uma fração fixa, não um modelo de
  escolha de modo sensível a preço. Uma abordagem logit (como a do
  NASA/Booz Allen Hamilton, 2018) seria mais defensável, mas exigiria dados
  de tarifa e valor do tempo por segmento que não temos.
- **Congestionamento do espaço aéreo / regras de tráfego aéreo (DECEA)**:
  fora de escopo — o problema já é suficientemente complexo como problema
  de localização; controle de tráfego aéreo é um problema operacional
  subsequente à decisão de localização.
- **Velocidade terrestre única para acesso e para a linha de base**: usamos
  a mesma `v_acesso` tanto no trecho de acesso/egresso quanto na viagem
  direta de linha de base `t0_ij`. Isso **subestima** a velocidade da
  viagem direta em trajetos longos (que na realidade usariam vias
  expressas/marginais, mais rápidas que a média usada aqui) — ou seja, o
  modelo tende a **superestimar o benefício de tempo da UAM** para pares OD
  distantes. É uma limitação identificada, não escondida (ver
  `app/scripts/07_experimentos.R`, aviso explícito nos resultados).

## 8. Relação com as 4 análises obrigatórias (§4.4)

| Análise | Onde |
|---|---|
| Relaxação linear vs. original | `app/scripts/07_experimentos.R`, seção "Relaxação" |
| Interpretação do dual | idem, seção "Dual" — duais das restrições (2)-(3) por vertiporto candidato |
| Sensibilidade | `app/scripts/07_experimentos.R`, varia `θ`, `v_acesso`, `D_min`, corte de renda |
| Curva de implantação | `app/scripts/07_experimentos.R`, varia `p` de 1 a 8 |

## 9. Redução de instância

A base OD 2017 tem 517 zonas. Uma formulação de hub de alocação múltipla
tem `O(|Z|² · |K|²)` variáveis contínuas — com 517 zonas isso seria da ordem
de `517⁴ ≈ 7×10¹⁰` variáveis, computacionalmente inviável para qualquer
solver, e especialmente para `lpSolve`, que monta a matriz de restrições
**densa** em memória (não é um solver esparso como Gurobi/CPLEX/CBC).

Decisão: agregar as 517 zonas em **8 macrorregiões** por k-means ponderado
por viagens produzidas (`app/scripts/02_macrorregioes.R`), usando o mesmo
conjunto de 8 regiões como candidatos a hub. Com isso:

- pares OD elegíveis: 21 (de 56 possíveis, após filtro de distância+renda)
- variáveis `x_ijkl`: `21 pares OD × 8×7 pares de hub = 1.176`
- variáveis `h_k`: 8 (as únicas binárias)
- restrições: `21 (constraint 1) + 21×8 (constraint 2) + 21×8 (constraint 3) + 1 (constraint 4) ≈ 379`

Uma matriz densa de ~1.176 colunas × ~379 linhas (~445 mil células) resolve
em segundos no `lpSolve`, permitindo resolver o modelo dezenas de vezes
(curva de implantação + sensibilidade) dentro do tempo da sessão. O preço
dessa redução: a resolução espacial fica grosseira (8 regiões cobrindo toda
a RMSP) e zonas administrativamente distintas com fluxo relevante entre si
podem cair na mesma macrorregião, "escondendo" uma viagem intra-região que
poderia se beneficiar de UAM. Registrado como limitação explícita — uma
instância com mais regiões (ex.: as 96 subprefeituras/distritos de SP + os
39 municípios da RMSP) exigiria um solver MILP esparso de verdade (CBC,
Gurobi, HiGHS), fora do escopo desta entrega com `lpSolve`.
