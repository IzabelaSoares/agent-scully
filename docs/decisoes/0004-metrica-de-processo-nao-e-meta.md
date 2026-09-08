# 0004 — Métrica de processo é instrumento, nunca meta

08/09/2026 · aceita

## Contexto

A [SPEC](../SPEC.md) §8 é a contribuição original deste projeto: publicar
métricas do **funil** de bugs — tempo até triagem, tempo por estado, idade do
trabalho em curso, taxa de reabertura, taxa de duplicata, vazão contra influxo —
ao lado do estado que o laudo já reporta.

O motivo é que "17 bugs parados, 8 com prazo estourado" gera pânico na segunda e
indiferença na quinta, e não diz **onde a fila engasga**.

E aqui aparece o risco de trazer essas métricas para um relatório que o time
inteiro lê toda manhã: **toda métrica publicada com regularidade é candidata a
meta**, dita ou não. Basta alguém perguntar duas vezes "por que o tempo de
triagem subiu" para que o número passe a ser gerenciado em vez de observado.

Cada uma delas é trivialmente gamificável, e as jogadas são todas ruins:

| Métrica | Como se melhora sem melhorar nada |
|---|---|
| tempo até triagem | triar errado, rápido |
| tempo por estado | mover o card antes de fazer o trabalho |
| idade do trabalho em curso | fechar o antigo como "não reproduz" |
| taxa de duplicata | parar de marcar duplicata |
| vazão | quebrar um bug em três |

## Decisão

As métricas de funil são **instrumento de diagnóstico**, e isso está escrito na
SPEC, no laudo e nesta entrada. Concretamente:

- **Nenhuma delas tem alvo numérico**, e o laudo não usa 🔴/🟡 nelas — os
  símbolos de alerta ficam reservados a prazo, que é compromisso, e não a
  processo, que é observação.
- **p50 e p90, nunca média** ([SPEC](../SPEC.md) §8.1). A média com um bug de
  180 dias e nove de um dia é 19 dias, número que não descreve nenhum dos dez.
- **Amostra pequena sai como amostra crua**, com a contagem, e o laudo diz que é
  pequena — em vez de publicar percentil sobre quatro itens.
- **A leitura é comparativa contra a janela anterior**, não contra um alvo:
  "p90 de triagem subiu de 2 para 6 dias" é informação; "p90 acima da meta de 3
  dias" é cobrança.

## Alternativas descartadas

**Definir SLO de processo e alertar quando estourar.** Descartada: é
exatamente a transformação em meta, e traz o incentivo errado para dentro do
mecanismo que deveria detectá-lo.

**Não publicar as métricas, deixar sob consulta.** Descartada: métrica que não
aparece não muda decisão, e o objetivo do laudo é justamente ser o lugar onde a
informação chega sem ninguém buscar.

**Publicar só a tendência, sem valor absoluto.** Tentadora, e descartada: o
valor absoluto é o que permite conferir o cálculo. Tendência sem número é
inauditável, e a [SPEC](../SPEC.md) §11 exige que as métricas sejam validadas
contra conta feita à mão.

**Publicar média, "porque todo mundo entende".** Descartada: todo mundo entende
errado. A distribuição de idade de bug tem cauda longa por natureza, e é a cauda
que interessa.

## Consequências

**Boas:** a informação chega a quem decide sem virar cobrança de quem executa. E
o agente ganha a legitimidade de apontar padrão sistêmico
([SPEC](../SPEC.md) §8.2) sem que a sugestão soe como acusação.

**Ruins, e assumidas:**

- **Sem alvo, a métrica pode ser ignorada.** É um risco real, e é o risco menor:
  métrica ignorada não faz dano; métrica gamificada corrompe o dado e o
  processo junto.
- **Comparação contra janela anterior exige histórico**, o que atrasa a utilidade
  das primeiras semanas. É por isso que a Etapa 11 vem depois de o board ter
  rodado, e não antes.
- **A distinção é cultural e não é imposta por código.** Nada impede alguém de
  transformar o número em meta numa reunião. O que este registro faz é deixar
  escrito que a escolha foi deliberada — o que é o máximo que uma decisão de
  projeto pode fazer contra uma decisão de gestão.

## Como se revisita

Se a métrica for demonstravelmente ignorada por trimestres, a resposta é mudar
**como ela é apresentada** — comparação mais legível, menos números, exemplo
concreto ao lado —, nunca dar-lhe alvo.

A decisão se revisita se aparecer uma métrica de processo que seja
simultaneamente útil como alvo e não gamificável. Nenhuma das seis é.
