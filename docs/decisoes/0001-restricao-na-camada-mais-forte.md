# 0001 — A restrição vai na camada mais forte que a suporta

08/09/2026 · aceita

## Contexto

O agente tem credencial de escrita em três sistemas: o board de bug, o
repositório de código e o canal do laudo. Ele é conduzido por um modelo de
linguagem, o que significa que **toda restrição expressa em prosa é uma
restrição negociável**: um prompt suficientemente diferente, um contexto
suficientemente longo ou um caminho alternativo que ninguém previu, e a regra
não se aplica.

Três camadas podem impor uma restrição, e elas não têm a mesma força:

- **capacidade** — a ferramenta não sabe fazer o proibido
- **permissão** — o harness recusa a chamada
- **rule** — um arquivo de instrução pede que não se faça

## Decisão

Cada restrição vai na **camada mais forte que a suporta**, e a camada mais fraca
fica com o *porquê* — não com a garantia.

Consequências concretas: coletor só sabe fazer `GET`; o wrapper de liberação usa
o endpoint de assignee, que não tem como tocar em outro campo; a granularidade
"só em issue com a label" vira wrapper que **recusa**, e não frase que pede;
a lista de ferramentas permitidas é explícita (*allowlist*) em vez de uma lista
de negação.

## Alternativas descartadas

**Confiar nas rules, com prompt bem escrito.** Descartada: funciona até não
funcionar, e a falha é silenciosa e irreversível. Uma escrita indevida num board
compartilhado não se desfaz sem rastro.

**Só denylist no harness.** Descartada e a razão é específica: lista de negação
pressupõe uma pessoa como caso-padrão — chamada desconhecida abre prompt e
alguém decide. **Em job automático não existe esse alguém, e o que não estiver
negado executa.** A denylist continua, como segunda linha e como documentação do
que é proibido de propósito, mas não é a garantia.

**Permitir as ferramentas de MCP equivalentes às operações já permitidas.**
Descartada, e é a que mais parece redundância: **operação permitida não é
caminho permitido.** A restrição real ("label sempre injetada", "só em issue com
a label", "transição só com PR verificado") vive no wrapper. Um caminho que não
passa pelo wrapper é um caminho sem restrição, mesmo que a operação final seja a
mesma.

**Revisão humana de cada escrita.** Descartada para o caminho automático: não
sobrevive ao volume, e uma aprovação que se dá por hábito é pior que nenhuma —
ela transfere a responsabilidade sem transferir a atenção.

## Consequências

**Boas:** a garantia não depende do modelo. O conjunto do que o agente consegue
fazer é auditável lendo `tools/` e a allowlist, sem ler prompt nenhum.

**Ruins, e assumidas:**

- **Mais código.** Cada operação permitida custa um wrapper, e cada wrapper
  custa teste. É o preço, e é conhecido.
- **Rigidez.** Uma operação nova exige código novo, não uma frase nova. Isso
  torna a ampliação de escopo lenta de propósito — o que é bom para segurança e
  irritante no dia em que a ampliação é obviamente certa.
- **Falsa sensação de cobertura.** Restrição em código pode ter defeito. O
  antídoto é a suíte, com dublê que **registra as requisições recebidas** — é
  como se prova que uma recusa por regra não emitiu chamada, o que asserção
  sobre código de saída não prova.

## Como se revisita

Se uma restrição estruturalmente imposta se mostrar errada — recusar operação
legítima com frequência que atrapalhe —, o caminho é **corrigir o wrapper**, não
mover a restrição para uma camada mais fraca.

A decisão em si se revisita se aparecer uma camada mais forte que as três
(assinatura de operação verificada do lado do servidor, por exemplo). Aí ela
passa a ser a primeira escolha, e esta entrada é emendada.
