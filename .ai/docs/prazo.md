# Deadline policy — como o radar escolhe o prazo

> Referência consultada sob demanda. A política em si é
> [`.ai/politicas/prazo.yaml`](../politicas/prazo.yaml) — **é ela que vale**, e
> este arquivo descreve como lê-la. Quem a aplica é
> [`.ai/tools/coleta/board-radar.sh`](../tools/coleta/board-radar.sh). O
> raciocínio está em
> [`decisoes/0003`](../../docs/decisoes/0003-politica-de-sla-declarativa.md), e as
> tasks, em [`TASKS.md`](../../docs/TASKS.md) C1 e C2.

Board de bug não tem *um* campo de prazo: tem os que foram se acumulando, com
semântica diferente por origem do bug, e nem todos preenchidos. Qual deles vale
é decisão de negócio, e decisão de negócio que vira `if` em script fica errada
por inércia — o custo de ajustá-la passa a ser mudança de código, teste e
revisão para trocar a ordem de dois campos.

Por isso a política é dado. Ajustar a precedência é diff de uma linha no
`.yaml`, revisável por quem entende do negócio e não do bash.

## A política de hoje

A tabela abaixo é **gerada** da política. Ela não se edita à mão: o caso
`tests/casos/07-prazo.sh` falha quando ela diverge do `.yaml`, e é esse o ponto
— o mesmo valor em dois lugares diverge em semanas.

<!-- tabela gerada de .ai/politicas/prazo.yaml — não edite à mão -->

| Origem | Precedência dos campos de prazo | Sem nenhum preenchido |
|---|---|---|
| `cliente` | 1. `Prazo do cliente` · 2. `Data limite` · 3. `Prazo interno` | `idade_desde_criacao` |
| `interno` | 1. `Data limite` · 2. `Prazo interno` | `idade_desde_criacao` |

A origem sai do campo `Origem do bug`; vazio, vale `cliente`.
Fallback `idade_desde_criacao`: dias desde a criação da issue, declarados como idade e nunca como prazo.
Corrobora, e nunca decide: `Dias para o vencimento`.

Classificação — 🔴 prazo vencido na data de referência; 🟡 vence em até 3 dia(s); 🟢 o resto.
Sem prazo declarado, entra pela idade: 🟡 a partir de 14 dia(s) de vida, e **nunca** 🔴 — idade é estimativa desta casa, não promessa a estourar.

<!-- fim da tabela gerada -->

Mudou a política? Regrave o bloco e mande o diff junto no mesmo commit:

```bash
tests/prazo/verificar.py --gerar
tests/run.sh 07-prazo
```

## Como se lê

1. **A origem do bug decide a lista.** O campo de origem diz por onde ele
   chegou; vazio, vale a origem padrão — e o padrão é o palpite barato, não o
   confortável (a razão está ao lado do valor, no `.yaml`).
2. **Vale o primeiro campo preenchido**, na ordem da lista. Não há mistura, não
   há "o menor dos dois": precedência é ordem, e ordem é o que se lê sem
   executar nada.
3. **Nenhum campo preenchido não é bug sem prazo — é bug pela idade.** O
   fallback existe porque a alternativa é o bug sumir do radar, e quem some
   primeiro é a parte mais antiga da fila.
4. **A idade entra no laudo declarada como idade.** Estimativa desta casa
   apresentada como promessa é como um painel perde crédito, e perde de uma vez.
5. **O campo de corroboração nunca decide.** Ele é recalculado pelo board na
   cadência do board, então diverge da data por horas.
6. **Sem prazo, a classificação vai até 🟡 e para.** Bug que entra pela idade
   nunca é 🔴: não há promessa a estourar, e apresentar estimativa desta casa
   como promessa é como um painel perde crédito — de uma vez.

## Quem lê a política

[`.ai/tools/coleta/board-radar.sh`](../tools/coleta/board-radar.sh) (TASKS C2).
Ele devolve JSON com **só** o que o julgamento usa — chave, base (`prazo` ou
`idade`), prazo efetivo, campo de onde o prazo saiu, dias de atraso, dias de
idade e classificação — mais a contagem do que está sob controle, que é o que
deixa o laudo **afirmar** "prazos sob controle" em vez de deixar a seção vazia
([`SPEC.md`](../../docs/SPEC.md) §7).

A data de referência é injetável por `SCULLY_AGORA`, e isso não é conveniência:
**sem ela a classificação é intestável**, porque o mesmo comando muda de
resposta amanhã. `--amostra <arquivo>` roda sobre uma resposta salva, que é o
que permite conferir o número à mão sobre a mesma entrada (task C3).

O leitor do `.yaml` é [`.ai/tools/lib/politica.py`](../tools/lib/politica.py), e
é **um só**: o mesmo que a suíte usa para verificar a política. Dois leitores
deixariam a verificação passar sobre um arquivo que o radar lê de outro jeito, e
a divergência apareceria como número errado no laudo — sem nada falhando.

## O que este arquivo garante, e o que não

**Garante**, por teste (`tests/casos/07-prazo.sh`, sobre
[`tests/prazo/verificar.py`](../../tests/prazo/verificar.py)):

- a política é legível no subconjunto declarado, e o que sai dele é recusado
  com o número da linha — nunca lido pela metade;
- toda origem tem lista de campos não vazia e fallback declarado;
- todo valor traz a razão ao lado ou imediatamente acima;
- os limiares da classificação estão declarados, em dias inteiros;
- **nenhum nome de campo de prazo aparece literal em script**;
- a tabela acima é a que sai do `.yaml`.

**Garante também**, por teste (`tests/casos/08-radar-prazo.sh`, sobre
`tests/fixtures/board/`): que o radar aplica esta precedência, que a
classificação muda quando o `.yaml` muda, e que ela muda quando a data de
referência muda.

**Não garante:** que a consulta ao board funcione. O board do alvo nasce na
Etapa 5 e ainda não existe, então o caminho de rede do radar está escrito e
**não foi exercitado contra board nenhum**. O que a suíte exercita é a
normalização e a classificação, sobre amostra. Retentativa e o estado de fonte
caída são a task C4; até lá, falha de coleta sai como status ≠ 0 — nunca como
fila vazia.

## Onde não mexer

O **id numérico** do campo não entra neste repositório: o coletor resolve nome →
id contra o próprio board, em execução. Id de campo customizado identifica a
instância de quem o tem, e identificador de instância de terceiro é justamente o
que `tests/casos/00-sanitizacao.sh` existe para barrar
([`decisoes/0002`](../../docs/decisoes/0002-sanitizacao-verificada-por-teste.md)).

Os nomes de campo são os do board do **alvo de demonstração**
([`docs/ALVO.md`](../../docs/ALVO.md)) — a empresa é declaradamente fictícia, e
nada aqui descreve board de terceiro.
