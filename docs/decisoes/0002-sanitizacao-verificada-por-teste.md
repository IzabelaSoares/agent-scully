# 0002 — Sanitização é verificada por teste, não por revisão

08/09/2026 · aceita

## Contexto

Este repositório é público e deriva de conhecimento adquirido em trabalho
privado. O que se transporta é **engenharia** — a forma do agente, o modelo de
permissão, as armadilhas de ferramenta, o desenho do contrato de saída. O que
não se transporta é **qualquer identificador**: nome de empresa, domínio de
instância, prefixo de chave de issue, id de entidade de observabilidade, id de
grupo de helpdesk, nome de pessoa, nome de repositório interno.

Duas propriedades do problema decidem a solução:

1. **O repositório vai crescer por meses.** A atenção que se aplica ao primeiro
   commit não é a que se aplica ao quadragésimo, e o vazamento provável não é o
   deliberado — é o exemplo copiado às pressas para ilustrar um formato.
2. **O erro é irreversível.** Conteúdo publicado em repositório público fica em
   cache de busca, em fork e em espelho. `git push --force` não desfaz, e o
   histórico reescrito é ele mesmo um sinal do que havia ali.

## Decisão

A sanitização é verificada por `tests/casos/00-sanitizacao.sh`, que varre todo
arquivo rastreado e **falha o CI**. É a
[decisão 0001](0001-restricao-na-camada-mais-forte.md) aplicada ao próprio
repositório: a restrição na camada mais forte disponível, que aqui é o CI.

A verificação tem **duas metades**, e a divisão resolve um problema que a
primeira versão desta decisão não tinha visto: **uma lista de termos proibidos
em texto claro anuncia a origem** — publica exatamente a informação que ela
existe para proteger.

- **`padroes.txt` — classes, em texto claro.** Expressão regular para o que se
  reconhece pela *forma*: domínio de instância de SaaS, prefixo de token, id de
  campo customizado, chave de issue de outro board, e-mail corporativo, IP de
  rede privada. Nada a esconder: descreve formatos públicos, e é a metade
  generalizável — serve a qualquer repositório com o mesmo problema.
- **`tokens.sha256` — literais, como hash salgado.** O verificador quebra cada
  arquivo em tokens, aplica o mesmo hash e compara. **Pega o literal sem
  publicá-lo.**

Duas propriedades do desenho que não são óbvias:

**A falha reporta arquivo e linha, nunca o termo.** Log de CI de repositório
público é público, e um teste que imprime o que encontrou publica o que a lista
existe para não publicar. Quem escreveu o commit reconhece o termo ao abrir a
linha.

**A lista é ela mesma verificada.** Lista vazia passaria em tudo e não
protegeria nada — é o modo de falha mais perigoso de um teste de negação, porque
ele se apresenta como sucesso. Três asserções cobrem isso: a lista de padrões
não está vazia, a de hashes não está vazia, e um canário plantado é
efetivamente pego.

## Alternativas descartadas

**Revisar com cuidado antes de cada push.** Descartada pela propriedade 1: não
escala, e falha exatamente quando o repositório já é grande o bastante para o
vazamento passar batido.

**Hook de `pre-commit`.** Descartada como **garantia** — hook é local, não é
versionado com força, e `--no-verify` existe. Fica como conveniência opcional; a
garantia é o CI, que ninguém contorna sem PR.

**Reescrever o histórico se algo vazar.** Descartada como plano: é remediação, e
remediação incompleta por natureza (propriedade 2). Continua sendo o que se faz
num incidente, mas não é o que se planeja.

**Não derivar nada de trabalho privado.** Descartada por ser a resposta errada à
pergunta certa. Experiência de engenharia é do engenheiro; identificador é da
organização. A linha existe e é nítida — o que faltava era um mecanismo que a
sustentasse sem depender de vigilância.

**Publicar a lista de termos em texto claro.** Era a primeira versão desta
decisão, e está descartada: a lista nomeia a origem, e publicá-la num
repositório público entrega de graça o que a sanitização toda existe para não
entregar.

**Manter a lista literal fora do repositório** — arquivo local, ou secret de
CI. Descartada nas duas formas. Arquivo local não roda no CI e cai na mesma
objeção do hook. Secret de CI romperia a propriedade de que **a suíte roda sem
nenhum secret**, que é o que permite a qualquer pessoa clonar e rodar o mesmo
comando — e colocaria a lista num sistema de terceiro para protegê-la de ser
lida por terceiros.

## Consequências

**Boas:** o custo da sanitização passa a ser pago uma vez, na escrita da lista,
em vez de continuamente em atenção. E a lista se torna documentação executável
da fronteira.

**Ruins, e assumidas:**

- **O hash é obfuscação, não sigilo.** O sal está no repositório, e um ataque de
  dicionário recupera termo curto em segundos. **Isto é aceito e está escrito**:
  o objetivo é não ter a lista em texto claro para quem abre o arquivo, não
  resistir a quem ataca. Nada que seja credencial entra na lista — credencial
  não se protege por `grep`, se rotaciona.
- **Diagnóstico mais difícil.** A falha diz onde, não o quê. É o preço direto de
  não publicar o termo, e recai sobre quem tem o contexto para resolver em
  segundos.
- **Token, não substring.** A metade dos hashes casa token alfanumérico
  completo, então um termo grudado em outra palavra sem separador escapa. A
  metade dos padrões cobre os casos que importam — domínio e prefixo de token —,
  e o limite está escrito em `tests/sanitizacao/README.md`.
- **Falsos positivos.** Um termo genérico na lista faz o CI falhar por engano. O
  antídoto é lista curta, específica e comentada.
- **Cobertura limitada ao literal.** O teste pega o identificador; não pega
  paráfrase que descreva um sistema interno com precisão suficiente para
  identificá-lo. Essa parte continua sendo julgamento — e é por isso que a
  [SPEC](../SPEC.md) §9 mantém a regra além do teste.

## Como se revisita

Um falso positivo recorrente é motivo para ajustar **o termo**, nunca para
remover a verificação.

A decisão se revisita se aparecer verificação melhor que o literal — detecção
por padrão, por exemplo. Ela **acrescenta**; não substitui a lista.
