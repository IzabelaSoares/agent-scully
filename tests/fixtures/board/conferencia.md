# Hand check — a conferência do radar sobre a amostra

> **Este arquivo é a conferência à mão exigida pela task C3**
> ([`TASKS.md`](../../../docs/TASKS.md)). Ele não é documentação sobre o teste:
> ele **é** o número esperado, e `tests/casos/09-conferencia.sh` falha quando o
> radar deixa de reproduzi-lo.

O radar de prazo (`.ai/tools/coleta/board-radar.sh`) devolve número que vai
virar linha de laudo. Número de laudo que ninguém conferiu é número em que
ninguém deveria acreditar — e conferir uma vez, no terminal de quem escreveu,
não conta: a conferência morre no histórico de conversa daquela pessoa, e o
radar fica livre para mudar de resposta depois.

Por isso a conta está escrita aqui, **célula a célula**, e é daqui que o caso da
suíte tira o esperado. Mudar o comportamento do radar passa a exigir mudar esta
tabela — que é um ato deliberado, visível no diff, com a conta nova ao lado da
antiga (é a mesma regra do golden file, [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)).

## Como esta conferência foi feita

Com a política ([`.ai/politicas/prazo.yaml`](../../../.ai/politicas/prazo.yaml)),
a amostra ([`amostra.json`](amostra.json)) e uma subtração de datas — **sem
rodar o radar**. A ordem importa: número conferido depois de ver a saída do
programa não é conferência, é concordância.

A subtração é sempre a mesma, e sempre com o mesmo sinal:

```
número = data de referência − data que valeu
```

Positivo é dia que já passou (atraso, ou idade); negativo é dia que ainda vem.
É o que torna `-2` legível como «vence depois de amanhã» sem nenhuma outra
convenção.

**O campo que valeu é citado pela posição na precedência da política**
(`cliente[1]` é o primeiro campo da lista da origem `cliente`), e nunca pelo
nome. Nome de campo mora num lugar só — a política —, e é de lá que o caso o
resolve na hora de comparar ([`decisões 0003`](../../../docs/decisoes/0003-politica-de-sla-declarativa.md)).

## A data de referência

<!-- referencia: 2026-09-14 -->

`2026-09-14`, injetada por `SCULLY_AGORA`. Sem ela a conferência valeria por um
dia só: o mesmo comando mudaria de resposta amanhã, e a tabela abaixo
envelheceria em silêncio.

## Issue a issue

| Chave | Origem aplicada | Base | Campo que valeu | Conta | Número | Classificação |
|---|---|---|---|---|---|---|
| MRD-101 | `cliente`, pelo rótulo | prazo | `cliente[1]` | 2026-09-14 − 2026-09-05 | 9 | 🔴 |
| MRD-102 | `interno`, pelo rótulo | prazo | `interno[1]` | 2026-09-14 − 2026-09-16 | -2 | 🟡 |
| MRD-103 | `cliente`, pelo padrão (campo vazio) | prazo | `cliente[2]` | 2026-09-14 − 2026-09-14 | 0 | 🟡 |
| MRD-104 | `cliente`, pelo rótulo | idade | — | 2026-09-14 − 2026-08-01 | 44 | 🟡 |
| MRD-105 | `interno`, pelo rótulo | prazo | `interno[2]` | 2026-09-14 − 2026-10-30 | -46 | 🟢 |
| MRD-106 | `cliente`, pelo rótulo | idade | — | 2026-09-14 − 2026-09-10 | 4 | 🟢 |
| MRD-107 | `cliente`, pelo padrão (rótulo desconhecido) | prazo | `cliente[2]` | 2026-09-14 − 2026-09-01 | 13 | 🔴 |

### Por que cada linha é essa linha

- **MRD-101** — rótulo de origem `Cliente`, que a política manda ler como
  `cliente`. O primeiro campo da precedência de `cliente` está preenchido, então
  é ele que vale, e o segundo não é olhado. A data que valeu já passou: **9 dias
  de atraso, 🔴**. O numérico de corroboração da amostra diz `6`, isto é, «ainda
  vai vencer» — e **não decide**: o board o recalcula na própria cadência, e é
  exatamente por discordar aqui que ele está na amostra.
- **MRD-102** — rótulo `Monitoramento`, que é origem `interno`. O campo de
  promessa externa está preenchido por resíduo de triagem e **fica de fora**: a
  precedência de `interno` não o inclui. Vale o primeiro campo da lista de
  `interno`, que vence daqui a dois dias. Dois é menor ou igual à janela de três
  dias da política: **🟡**.
- **MRD-103** — campo de origem vazio, que cai na origem padrão `cliente`. O
  primeiro campo da lista está vazio; vale o segundo, e ele vence **hoje**. A
  conta dá zero, e zero **não é atraso**: o prazo de hoje ainda não estourou.
  Dentro da janela de três dias: **🟡, e não 🔴**.
- **MRD-104** — nenhum dos três campos de `cliente` preenchido (o segundo tem
  espaços em branco, que para a precedência é o mesmo que vazio). Entra pelo
  fallback, contando da criação: **44 dias de idade**. Acima do corte de
  catorze, então **🟡** — e nunca 🔴, porque idade é estimativa desta casa e não
  promessa a estourar
  ([`decisões 0005`](../../../docs/decisoes/0005-idade-nao-e-prazo-na-saida-do-radar.md)).
- **MRD-105** — origem `interno`; o primeiro campo da lista está vazio, vale o
  segundo. Vence daqui a 46 dias, muito além da janela: **🟢**. Está na amostra
  para que a contagem de «sob controle» tenha o que contar, e para que a troca de
  política do caso 08 tenha um 🟢 para mover.
- **MRD-106** — sem nenhum campo e recém-criado: **4 dias de idade**, abaixo do
  corte de catorze. **🟢**.
- **MRD-107** — rótulo `Parceiro`, que a política **não** conhece. Cai na origem
  padrão, e é a linha que prova que rótulo desconhecido **não some do radar**.
  Com o padrão, vale o segundo campo de `cliente`: venceu há 13 dias, **🔴**.

## Os agregados

| Agregado | Conferido à mão |
|---|---|
| `total` | 7 |
| `examinados` | 7 |
| `truncado` | false |
| `sob_controle` | 2 |
| `itens` | MRD-107 · MRD-101 · MRD-104 · MRD-103 · MRD-102 |

- **`total` e `examinados`** — a amostra declara sete e traz sete, e diz que é a
  última página. Nada foi truncado, e por isso `truncado` é `false`. (A amostra
  que **é** truncada é outro arquivo, e o caso 08 a confere.)
- **`sob_controle`** — os dois 🟢 da tabela acima, MRD-105 e MRD-106. Eles são
  contados e **não** listados: é esse número que deixa o laudo afirmar «prazos
  sob controle» em vez de deixar a seção vazia.
- **`itens`** — os cinco que não são 🟢, na ordem em que o laudo os lista:
  primeiro os 🔴, depois os 🟡, e dentro de cada classe quem espera há mais tempo
  na frente. Daí `MRD-107` (13 dias de atraso) antes de `MRD-101` (9), e, entre
  os amarelos, `MRD-104` (44 dias de idade) antes de `MRD-103` (vence hoje) e de
  `MRD-102` (vence em dois dias).
- Cinco itens mais dois sob controle são sete: **ninguém sumiu pelo caminho**. É
  a conta que a tabela acima tem de fechar, e o caso 09 a refaz.
