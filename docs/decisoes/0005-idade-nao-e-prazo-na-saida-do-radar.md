# 0005 — Idade e prazo são campos separados na saída do radar

14/09/2026 · aceita

## Contexto

A política de prazo ([`0003`](0003-politica-de-sla-declarativa.md)) já resolve
qual campo vale, e resolve também o que fazer quando **nenhum** está preenchido:
o bug entra pelo *fallback*, pela idade, porque a alternativa é ele sumir do
radar — e quem some primeiro é a parte mais antiga da fila.

Resolver isso na política deixou uma pergunta aberta do outro lado, na **saída**
do coletor: os dois números — "está nove dias atrasado" e "tem quarenta e quatro
dias de vida" — são a mesma coisa para quem lê o JSON? Não são, e a diferença é
de natureza, não de grau: um é **promessa** feita por alguém a alguém, e o outro
é **estimativa desta casa**.

A confusão entre os dois tem consequência conhecida e cara: o laudo passa a
apresentar número da casa como compromisso externo, e um painel que faz isso
perde crédito de uma vez — ninguém confere o resto.

## Decisão

A saída do radar carrega `base` (`prazo` ou `idade`) e **dois campos numéricos
separados**, `dias_de_atraso` e `dias_de_idade`, cada um preenchido só na base
que lhe cabe. E a classificação por idade **para em 🟡**: bug sem prazo declarado
nunca é 🔴, porque não há promessa a estourar.

A estrutura do dado carrega a regra. Com um campo só, confundir os dois fica a um
descuido de distância; com dois, não tem como acontecer.

## Alternativas descartadas

**Um campo `dias`, com `base` dizendo o que ele conta.** Descartada: é a mesma
informação em menos bytes e com um significado a mais por campo. Quem escreve o
gerador do laudo lê `dias` e formata; o `base` fica dois campos acima e se
esquece. O modo de falha — "44 dias de atraso" num bug que ninguém prometeu — é
silencioso e passa em qualquer teste que não o procure de propósito.

**Deixar o bug sem prazo fora da saída, e contá-lo à parte.** Descartada porque
é a invisibilidade que o *fallback* da política existe para impedir, movida do
`.yaml` para o coletor. O bug antigo sem campo preenchido é justamente o que
precisa aparecer.

**Classificar idade como 🔴 acima de algum corte.** Descartada: qualquer corte
aqui é desta casa, e pintá-lo de vermelho o apresenta com a força de um prazo
vencido. 🔴 fica reservado ao fato verificável — a data passou.

**Deixar o laudo resolver a distinção no texto.** Descartada pela régua da
[SPEC](../SPEC.md) §4: o que pode ser estrutura não vira convenção de
formatação. Uma regra que só existe na camada de texto é uma regra que o próximo
template desfaz.

## Consequências

**Boas:** o JSON é autoexplicativo e o teste da saída é um conjunto **fechado**
de campos — campo novo derruba o caso, de propósito. O laudo consegue escrever
"há 44 dias na fila" e "9 dias atrasado" sem inventar qual dos dois é.

**Ruins, e assumidas:**

- **Um campo nulo em todo item.** É desperdício visível num JSON pequeno, e o
  preço de tornar a confusão impossível.
- **Mais um conceito para quem lê pela primeira vez.** Mitigado por o `base` vir
  antes dos números, e pelo cabeçalho do coletor dizer por que são dois.
- **A contagem de 🟢 não vira lista.** Quem quiser auditar item a item o que está
  sob controle precisa rodar o radar com outra referência ou outra política; a
  contagem serve à afirmação do laudo ([SPEC](../SPEC.md) §7), não à auditoria.

## Como se revisita

Se aparecer uma terceira base — prazo herdado de outro sistema, por exemplo —, a
solução não é um terceiro campo numérico: aí são três, e três campos mutuamente
nulos viraram uma união mal escrita. O gatilho concreto é esse: **a segunda base
sem prazo declarado**. Nesse dia o certo é `{base, dias, unidade}` com validação,
e não mais um `dias_de_*`.
