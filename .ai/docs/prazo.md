# Deadline policy — como o radar escolhe o prazo

> Referência consultada sob demanda. A política em si é
> [`.ai/politicas/prazo.yaml`](../politicas/prazo.yaml) — **é ela que vale**, e
> este arquivo descreve como lê-la. O raciocínio está em
> [`decisoes/0003`](../../docs/decisoes/0003-politica-de-sla-declarativa.md), e a
> task, em [`TASKS.md`](../../docs/TASKS.md) C1.

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

## O que este arquivo garante, e o que não

**Garante**, por teste (`tests/casos/07-prazo.sh`, sobre
[`tests/prazo/verificar.py`](../../tests/prazo/verificar.py)):

- a política é legível no subconjunto declarado, e o que sai dele é recusado
  com o número da linha — nunca lido pela metade;
- toda origem tem lista de campos não vazia e fallback declarado;
- todo valor traz a razão ao lado ou imediatamente acima;
- **nenhum nome de campo de prazo aparece literal em script**;
- a tabela acima é a que sai do `.yaml`.

**Não garante:** que exista coletor. Não existe — o radar é a task C2, e até ele
chegar esta política é contrato verificado e nada mais. Diretório e etapa vazios
neste repositório são etapa não começada, não lacuna esquecida.

## Onde não mexer

O **id numérico** do campo não entra neste repositório: o coletor resolve nome →
id contra o próprio board, em execução. Id de campo customizado identifica a
instância de quem o tem, e identificador de instância de terceiro é justamente o
que `tests/casos/00-sanitizacao.sh` existe para barrar
([`decisoes/0002`](../../docs/decisoes/0002-sanitizacao-verificada-por-teste.md)).

Os nomes de campo são os do board do **alvo de demonstração**
([`docs/ALVO.md`](../../docs/ALVO.md)) — a empresa é declaradamente fictícia, e
nada aqui descreve board de terceiro.
