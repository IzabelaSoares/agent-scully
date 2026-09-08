# 0003 — A política de prazo é dado declarativo, não código

08/09/2026 · aceita

## Contexto

Board de bug de time real não tem *um* campo de prazo. Tem três ou quatro, que
foram acumulados: um legado que era o prazo do cliente até uma migração, um novo
que passou a ser, um interno que conta a partir de quando a tarefa chegou ao
desenvolvimento, e um numérico de corroboração. Qual deles vale **depende da
origem do bug** — reportado por cliente ou nascido interno —, e nem todos estão
preenchidos.

Isso produz três armadilhas que não são hipotéticas:

- **Precedência invertida escolhe o prazo mais frouxo** e reporta "no prazo" com
  a promessa ao cliente já vencida.
- **Sem *fallback*, a maior parte da fila fica invisível** — bugs que só têm o
  campo legado preenchido simplesmente não aparecem, inclusive os mais antigos.
- **A regra muda** por decisão de negócio, sem aviso à automação.

## Decisão

A política de prazo é **dado**: `.ai/politicas/prazo.yaml` declara, por origem de
bug, quais campos valem, em que precedência e qual o *fallback* — com a razão de
cada escolha ao lado do valor. Nenhum nome de campo de prazo aparece literal em
script, e um caso da suíte falha quando o arquivo e a documentação divergem.

O mesmo vale para todo limiar de calibragem ([`../SPEC.md`](../SPEC.md) §9.1):
saúde, janela do amarelo, cota de linhas, teto por execução, limiar de padrão
sistêmico.

## Alternativas descartadas

**`if` no coletor.** Descartada: transforma decisão de negócio em mudança de
código, com teste e revisão de código, para trocar a ordem de dois campos. O
custo do ajuste passa a ser tão alto que a regra fica errada por inércia.

**Regra em prosa, na documentação, e o script confiando no modelo.** Descartada
porque aritmética de data e escolha de campo são exatamente o que **não** deve
depender de modelo: hoje o modelo acerta as contas, mas acerta por capacidade, e
não por construção. A régua da [SPEC](../SPEC.md) §4 é clara — se pode ser
script, é script.

**Um adaptador por board, com interface.** Descartada **por enquanto**: é
abstração construída sobre um caso só, que descreve aquele caso com mais
arquivos. O `.yaml` já isola a parte que de fato varia; o adaptador espera o
segundo board de verdade (ROADMAP H1).

**Deixar o limiar literal no script, "porque é só um número".** Descartada: o
número aparece em três lugares em seis semanas, e então os três divergem. O
teste que compara arquivo e documentação existe por causa disso.

## Consequências

**Boas:** ajustar prazo é diff de uma linha, revisável por PR por quem entende
do negócio e não do bash. A razão viaja junto do valor, então quem ajusta lê
por que estava daquele jeito. E a política vira o artefato que se mostra a
quem pergunta "como vocês decidem o que está atrasado".

**Ruins, e assumidas:**

- **Uma indireção a mais** para depurar: o comportamento não está onde o código
  está.
- **`.yaml` mal escrito falha em execução**, não em compilação. Mitigado por
  validação de schema no início da execução, que é obrigação do coletor — e a
  falha aparece como falha, nunca como lista vazia.
- **Tentação de colocar regra no arquivo de calibragem.** A [SPEC](../SPEC.md)
  §9.1 separa os dois: o que não se ajusta sem decisão explícita não é
  calibragem e não vive ali.

## Como se revisita

Se a política crescer até precisar de condicional aninhado, ela deixou de ser
dado e virou linguagem — e aí o certo é um adaptador de verdade, com interface,
e não um `.yaml` que finge ser programa.

O gatilho concreto: a primeira regra que não se expresse como
`origem → lista ordenada de campos → fallback`.
