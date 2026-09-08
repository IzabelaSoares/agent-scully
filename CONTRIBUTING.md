# Contribuir

Convenções deste repositório. Valem também para a autora — em particular a de
merge, que é a única que não tem exceção.

## Idioma

**Tudo em português brasileiro:** código, comentário, mensagem de commit,
documentação e texto de saída. **Nome de arquivo e título H1 em inglês.**

Não é preferência estética. O laudo é lido por quem está de plantão, e um
relatório meio em inglês custa um instante de tradução a cada leitura — todo
dia, por meses.

## Branch e PR

| Prefixo | Para |
|---|---|
| `feat/` | funcionalidade nova |
| `fix/` | correção |
| `docs/` | documentação, especificação, decisão |
| `ops/` | CI, agendamento, ferramental |
| `test/` | só teste |

Base sempre `main`. **PR sempre, inclusive para a autora** — é o que dá revisão,
CI e histórico legível a quem olhar depois.

**Merge é humano.** [SPEC §9](docs/SPEC.md). Não há merge automático por CI
verde, e não haverá: **CI verde é pré-condição, não autorização**, e a primeira
exceção é o fim da garantia.

## Commit

`<tipo>: <o que mudou, no imperativo>`, em pt-BR, com o corpo respondendo **por
quê** quando o quê não é óbvio pelo diff.

```
feat: radar de prazo lê a política declarativa em vez de literal

O campo de prazo era escolhido por `if` no coletor. Trocar a precedência
exigia mudança de código, teste e revisão — custo alto o bastante para a
regra ficar errada por inércia. Ver docs/decisoes/0003.
```

## Antes de abrir o PR

```bash
tests/run.sh
```

**Mudança em `.ai/tools/` sem rodar a suíte é mudança não verificada.** E:

- **`shellcheck` ausente faz a suíte falhar**, não pular. Instale antes.
- **Mudar o golden file é ato deliberado**, e o diff vai no commit. Refatoração
  que exige mudar o golden mudou comportamento e não é refatoração.
- **Limiar novo vai para `.ai/politicas/`**, com a razão ao lado — nunca literal
  em script ([SPEC §9.1](docs/SPEC.md)).
- **Armadilha descoberta vai para a SPEC §10, com data e evidência.** Sem a
  evidência, a próxima pessoa desfaz.
- **Mudou a forma do sistema?** Uma entrada em
  [`docs/decisoes/`](docs/decisoes/README.md), com as cinco seções — **incluindo
  as alternativas descartadas e o motivo do descarte**.

## O que não entra, nunca

Identificador de empresa, cliente, instância de terceiro ou sistema interno de
qualquer organização. Verificado por `tests/casos/00-sanitizacao.sh`, que falha
o CI — ver
[`docs/decisoes/0002`](docs/decisoes/0002-sanitizacao-verificada-por-teste.md).

Credencial não entra nem como exemplo plausível. `.env.example` documenta o
**contrato** da variável — o que é, em que conta, quem emite, qual escopo, qual
validade — e nunca um valor que pareça real.
