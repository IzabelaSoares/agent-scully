# 0007 — Falha de coleta sai como estado na saída, não como status ≠ 0

16/10/2026 · aceita

## Contexto

Até aqui, toda falha do radar saía do mesmo jeito: status ≠ 0, motivo no
stderr, **nada** no stdout. Foi a escolha certa enquanto o coletor não tinha
quem o consumisse — ela torna impossível a saída pela metade, que parece
resposta.

A Etapa 3 muda a pergunta. O laudo tem de sair **assim mesmo** quando uma fonte
cai, com a seção marcada ([`SPEC`](../SPEC.md) §7), e tem de distinguir dois
estados que não são o mesmo: ⚠️ `indisponível no momento` — falhou nesta
execução, exige atenção — e 🚧 `ainda não integrada` — lacuna conhecida e
planejada. Com status ≠ 0 e stdout vazio, o gerador do laudo não recebe nada
que o permita escolher entre os dois, e ausência de saída é indistinguível de
"o coletor não rodou". A alternativa seria o gerador **inferir** o estado do
código de saída — ou seja, inventá-lo.

É a mesma tensão de sempre, agora do lado do contrato: o que não se pode é
nenhum dos dois estados virar número.

## Decisão

Os dois estados declarados saem **na própria saída**, com status **0**: uma
chave booleana para cada um (`indisponivel`, `nao_integrada`), presentes também
quando a coleta deu certo. Na saída de estado **não há** `total`, `examinados`,
`sob_controle` nem `itens` — a ausência é a regra na forma do dado.

Continua saindo 1, com nada no stdout, o que o coletor **não sabe reportar**:
política ausente, ferramenta ausente, resposta que ele não entende. A fronteira
é essa: falha reportada sai 0 porque reportar é ter conseguido responder; falha
que ele não sabe reportar sai ≠ 0 e pede uma pessoa.

Quanto se insiste antes de desistir é calibragem, e mora em
`.ai/politicas/coleta.yaml`. O que **conta** como erro transitório — 5xx, 429,
timeout — é contrato da [`SPEC`](../SPEC.md) §7 e fica no coletor.

## Alternativas descartadas

**Manter status ≠ 0 e nada no stdout.** Descartada: joga no gerador do laudo a
decisão de qual dos dois estados houve, e a única pista que ele teria é um
código de saída. Dois estados com significados opostos — um exige atenção hoje,
o outro é lacuna planejada — não cabem num número que já significa outra coisa.

**`itens: []` com uma flag de estado ao lado.** Descartada, e é a que mais
convida: a lista vazia continua lá, e todo consumidor que iterar `.itens` acerta
por acidente nos dias bons e erra calado no dia da falha. Lista vazia se lê como
"não havia nada". Sem a chave, quem pedir `.itens` lê `null`, que não se
confunde com nada.

**Um campo só, `estado: "ok" | "indisponivel" | "nao_integrada"`.** Descartada
por como ela falha quando um estado novo aparecer: o consumidor que compara
contra uma string que ainda não conhece cai no ramo errado em silêncio — e, se
a comparação for com acento ou com um `!=`, cai no ramo *saudável*, que é o pior
lado para errar. Com uma chave por estado, quem não conhece a chave nova
continua lendo corretamente as que conhece. É também a forma que o critério de
pronto da C4 nomeia, e [`0005`](0005-idade-nao-e-prazo-na-saida-do-radar.md) já
fixou neste repositório a régua de preferir a estrutura que torna a confusão
impossível à que a torna improvável.

**Sair 0 também quando a resposta não se entende.** Descartada: corpo ilegível
e política ausente não são "a fonte caiu", são "este coletor não sabe o que
fazer". Marcá-los no laudo como fonte indisponível mandaria para a ronda de
amanhã um defeito que precisa de uma pessoa hoje.

**Pôr a lista de erros transitórios na política.** Descartada: não é limiar, é
a definição de transitório, que a SPEC §7 fixa. E teria o modo de falha que o
leitor de política recusa nas listas de campo — uma lista vazia desligaria a
retentativa inteira, em silêncio.

**Documentar a política de coleta em `.ai/docs/`, como a de prazo.** Descartada
por ora: a de prazo tem uma tabela de precedência que se lê de fora do `.yaml`,
e é essa tabela que o teste compara. Aqui são quatro números com a razão ao
lado, e um segundo lugar para eles seria duplicação que diverge em semanas
([`CONVENTIONS`](../../.ai/CONVENTIONS.md)).

## Consequências

**Boas:** o gerador do laudo recebe o estado como **dado** e não tem o que
inventar; a suíte exercita os dois estados sem rede, com dublê de `curl`; e
saída vazia deixa de ser representável — não há lista a vir vazia.

**Ruins, e assumidas:**

- **Status 0 numa falha é contraintuitivo.** Quem encadear `radar.sh | jq
  '.itens[]'` recebe silêncio e nenhum erro. Mitigado por a chave sumir em vez
  de vir vazia — `.itens` é `null`, e `null[]` é erro de `jq`, não lista vazia —,
  mas é aresta de verdade, e o teste de contrato da Etapa 3 tem de cobrir o
  gerador recebendo os dois estados.
- **Duas chaves a mais em toda saída boa.** O preço de "a fonte respondeu" ser
  afirmação em vez de ausência.
- **O padrão está num coletor só.** Cada coletor novo das Etapas 6 a 8 repete a
  forma à mão até alguém extrair a parte comum para `tools/lib/`. Extrair agora
  seria adivinhar a forma de um coletor que ainda não existe.
- **Até seis segundos a mais por fonte caída**, no orçamento da ronda. É o
  teto que `coleta.yaml` fixa, e está lá para ser ajustado quando houver sete
  fontes e uma medida de quanto a ronda demora.

## Como se revisita

Dois gatilhos concretos. **O terceiro estado:** no dia em que uma fonte precisar
sair como "respondeu pela metade", duas chaves viram três mutuamente exclusivas,
que é uma união mal escrita — aí o certo é `estado` com vocabulário validado, e
o custo da migração é conhecido porque o conjunto de chaves da saída é
verificado como conjunto fechado. **O orçamento da ronda:** medida mostrando que
a espera das retentativas atrasa o laudo é ajuste de `coleta.yaml`, não desta
decisão — mas se o ajuste chegar a zero tentativa, o que se está dizendo é que
retentativa não vale o custo, e isso reabre a SPEC §7.
