# Revisão de literatura — modelos de localização de hubs e demanda UAM

Curta, focada no que fundamenta as escolhas de `app/formulacao.md` e de
`app/scripts/04_parametros.R`. Não é uma revisão sistemática.

## Localização de facilities / hubs (fundamenta a formulação)

1. **O'Kelly, M.E. (1987). "A quadratic integer program for the location of
   interacting hub facilities." *European Journal of Operational Research*,
   32(3), 393–404.**
   Formulação original de hub location como programa quadrático inteiro
   (alocação única): o custo de servir um par OD depende do produto de duas
   variáveis binárias de alocação, o que é exatamente a "interdependência
   entre localizações" que o enunciado do projeto exige representar. Usamos
   este artigo para justificar *por que* o problema é combinatório e não
   redutível a um ranking por demanda — mas não usamos sua formulação
   quadrática diretamente, porque `lpSolve` não resolve MIQP.

2. **Campbell, J.F. (1994). "Integer programming formulations of discrete
   hub location problems." *European Journal of Operational Research*,
   72(2), 387–405.**
   Linearização da formulação de O'Kelly via alocação múltipla (variáveis
   contínuas de fluxo por par de hubs, em vez de produtos de binárias). É a
   base direta da formulação adotada em `app/formulacao.md` §6 — as
   restrições (2)-(3) do nosso modelo seguem o padrão de agregação que
   Campbell usa para reduzir `O(n⁴)` restrições de ligação hub-fluxo para
   `O(n³)`.

3. **Alumur, S., & Kara, B.Y. (2008). "Network hub location problems: The
   state of the art." *European Journal of Operational Research*, 190(1),
   1–21.**
   Survey que classifica as famílias de hub location (mediana, cobertura,
   center, custo fixo) e suas variantes capacitadas/não-capacitadas. Usado
   para justificar a escolha específica de "p-hub median não-capacitado com
   alocação múltipla" dentre as alternativas listadas no enunciado (§4.2).

## Localização de vertiportos / demanda UAM (fundamenta os parâmetros)

4. **Booz Allen Hamilton / NASA (2018). "Urban Air Mobility (UAM) Market
   Study." NASA NTRS 20190001472.**
   Estudo de mercado que segmenta a demanda inicial de UAM por passageiros
   de alta disposição a pagar (correlacionada com renda/classe premium de
   viagem aérea comercial) e estima que o mercado de curto prazo fica em
   torno de 0,5% do mercado potencial irrestrito, mesmo em cenários sem
   restrições regulatórias severas. Usado para justificar (i) o filtro de
   renda da zona de origem como proxy de elegibilidade e (ii) a ordem de
   grandeza conservadora de `θ` (fração comportamental de adesão) em
   `app/scripts/04_parametros.R`.

5. **Rimjha, M., & Trani, A. (2021). "Commuter demand estimation and
   feasibility assessment for Urban Air Mobility in Northern California."**
   Estimativa de demanda de commuters para UAM com taxas de captura da
   ordem de poucos pontos percentuais da demanda elegível mesmo em cenários
   otimistas — usado para calibrar a faixa de sensibilidade de `θ` (2%–15%)
   em vez de um único valor pontual não testado.

6. **Ribeiro, N. et al. — revisão sistemática: "New infrastructures for
   Urban Air Mobility systems: A systematic review on vertiport location
   and capacity." *Journal of Air Transport Management* (2023).**
   Panorama dos métodos usados na literatura recente para localização de
   vertiportos (clustering de demanda, MCDA baseada em SIG, programação
   matemática) — confirma que abordagens de *facility/hub location*
   clássicas adaptadas são a corrente dominante, e não um método
   proprietário específico de UAM, o que sustenta a decisão de adaptar
   hub location clássico em vez de inventar uma formulação do zero.

## Valor do tempo (fundamenta a monetização ilustrativa do benefício)

7. **Small, K.A. (2012). "Valuation of travel time." *Economics of
   Transportation*, 1(1–2), 2–14.**
   Revisão de métodos de valor do tempo (VOT) como fração do
   salário-hora — usada apenas para a conversão *ilustrativa*
   tempo→R$ em `app/scripts/07_experimentos.R` (não é uma análise de
   custo-benefício rigorosa; ver ressalva no próprio script).
