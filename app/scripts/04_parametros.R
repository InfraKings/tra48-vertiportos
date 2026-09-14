# app/scripts/04_parametros.R
# Parametros assumidos pelo grupo para a hipotese de demanda capturavel e
# para os tempos generalizados de viagem. Cada um e' uma decisao explicita
# (ver handoff / app/formulacao.md) -- nao ha resposta oficial do enunciado
# para nenhum destes valores. Todos sao reexaminados na analise de
# sensibilidade (app/scripts/09_sensibilidade.R).

PARAMS <- list(
  ## --- Elegibilidade geografica -------------------------------------------
  # Distancia minima (km, linha reta entre macrorregioes) para um par OD ser
  # sequer considerado elegivel a UAM. Abaixo disso, o tempo de
  # acesso+egresso+overhead do voo domina qualquer ganho do trecho aereo
  # ("o acesso terrestre domina", Projeto_TRA48.pdf secao 2.2). Ordem de
  # grandeza: com overhead fixo de 8 min e velocidade de voo ~10x a
  # terrestre, o breakeven fica na faixa de poucos km; adotamos 8 km como
  # piso conservador.
  D_MIN_KM = 8,

  ## --- Elegibilidade socioeconomica ----------------------------------------
  # Percentil minimo de renda media familiar da zona de ORIGEM (Tabela 6,
  # OD2017) para a viagem ser considerada elegivel. Justificativa: o estudo
  # de mercado NASA/Booz Allen Hamilton (2018) segmenta a demanda inicial de
  # UAM por passageiros de tarifa premium / alta renda (ver
  # app/literatura.md). Terço superior de renda (percentil 66) das
  # macrorregioes como proxy de "capacidade de pagar tarifa premium".
  PERCENTIL_RENDA_MIN = 0.66,

  ## --- Fracao comportamental de adesao (dentre elegiveis) ------------------
  # Fracao das viagens ja elegiveis (distancia + renda) que de fato migraria
  # para UAM. NASA/Booz Allen Hamilton (2018) estima o mercado de curto
  # prazo em ~0,5% do TAM irrestrito; Rimjha & Trani (2021) obtem taxas de
  # poucos % em cenarios de demanda por commuters mesmo sob premissas
  # otimistas. Adotamos 5% como cenario "medio prazo" deliberadamente mais
  # otimista que o "curto prazo" da NASA, testado entre 2% e 15% na analise
  # de sensibilidade.
  THETA = 0.05,

  ## --- Velocidades e tempos ------------------------------------------------
  # Velocidade media de acesso/egresso terrestre (km/h). Nao localizamos um
  # numero unico e atual publicado pela CET-SP dentro do tempo desta sessao;
  # usamos uma ordem de grandeza tipica de via arterial congestionada em
  # pico na RMSP (bem abaixo do limite de 50-60 km/h nas marginais, que so
  # se aplica a vias expressas) e testamos 15-30 km/h na sensibilidade.
  V_ACESSO_KMH = 20,

  # Velocidade de cruzeiro do eVTOL (km/h). Usamos a Eve (subsidiaria da
  # Embraer, certificacao-alvo ANAC ~2027) por ser o unico fabricante com
  # processo de certificacao junto a' autoridade brasileira: ~125 mph =
  # ~201 km/h de cruzeiro. Ver app/literatura.md.
  V_CRUZEIRO_KMH = 200,

  # Overhead fixo por voo (h): embarque, seguranca, taxi, subida/descida.
  # 8 minutos, ordem de grandeza consistente com o turnaround de ~10 min
  # citado pela Archer para operacoes urbanas de curto alcance.
  T_OVERHEAD_VOO_H = 8 / 60,

  ## --- Malha viaria vs linha reta -------------------------------------------
  # Fator de sinuosidade: distancia real de deslocamento terrestre / distancia
  # em linha reta. 1.3 e' uma aproximacao usual em estudos de transporte
  # urbano (malha nao-euclidiana). Aplicado so ao trecho terrestre (acesso/
  # egresso); o trecho aereo usa distancia em linha reta (voo direto).
  FATOR_SINUOSIDADE = 1.3,

  ## --- Numero de macrorregioes / candidatos (ver 02_macrorregioes.R) -------
  N_REGIOES = 8
)
