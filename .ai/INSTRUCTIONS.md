# Agent Scully — instruções para agentes de código

> **Fonte única de verdade.** `CLAUDE.md` e `AGENTS.md` na raiz são symlinks para
> este arquivo. **Edite sempre aqui em `.ai/`** — nunca os symlinks.
> **Todo texto — código, comentários, commits e documentação — em português
> brasileiro.** Nome de arquivo e título H1 em inglês.

Agente de plantão: faz a **ronda** das fontes de um serviço, produz um laudo
verificável e mede o processo de bugs em volta dele. Ele **alimenta** quem está
de plantão — não substitui. O padrão de qualidade exigido sai daí, e está na
[`docs/SPEC.md`](docs/SPEC.md) §1.

⚠️ **O alvo vigiado é declaradamente fictício.** A empresa `Meridian` não
existe; o serviço `meridian-assist` é alvo de demonstração. Ver
[`docs/ALVO.md`](docs/ALVO.md) antes de escrever qualquer coisa que sugira
tráfego de cliente real.

## Estado atual

**Etapa 1** do [`docs/PLAN.md`](docs/PLAN.md), em curso — ambiente e
credenciais; a Etapa 0 (contrato e rede de segurança) está fechada. Não há
coletor implementado ainda: o que existe é a especificação, a suíte, o CI e a
biblioteca de ambiente (`.ai/tools/lib/env.sh`). Qualquer afirmação de que algo
"roda" precisa de teste que a sustente.

## Sumário

**Especificação e planejamento** — `docs/` na raiz:

| Documento | Quando ler |
|---|---|
| [`docs/SPEC.md`](docs/SPEC.md) | O que o agente é: papel, tese, escopo, modelo de permissão, contrato de saída, métricas de processo, regras inegociáveis, armadilhas, critérios de aceite. **É a referência de que saem plano e tasks.** |
| [`docs/PLAN.md`](docs/PLAN.md) | O que se constrói, em que ordem e por quê. As treze etapas. |
| [`docs/TASKS.md`](docs/TASKS.md) | As tasks da etapa em curso, com critério de pronto. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Horizontes depois do plano, e os riscos abertos. |
| [`docs/ALVO.md`](docs/ALVO.md) | O que é fictício e o que é real no alvo, e por quê. |
| [`docs/decisoes/`](docs/decisoes/README.md) | **O porquê de cada escolha — e o que foi descartado.** Leia antes de repropor uma ideia. |

**Referência (descritiva)** — `.ai/docs/`:

| Documento | Quando ler |
|---|---|
| [`docs/permissoes.md`](.ai/docs/permissoes.md) | A amarração das três camadas: qual restrição é imposta onde, e o que ainda é plano em vez de garantia. **Leia antes de mexer em `.claude/settings.json` ou em `.ai/tools/acoes/`.** |

**Meta** — [`CONVENTIONS.md`](.ai/CONVENTIONS.md): como este `.ai/` é
organizado, e onde vai cada arquivo novo.

`docs/`, `rules/`, `politicas/`, `templates/` e `skills/` dentro de `.ai/`
ganham conteúdo à medida que as etapas os exigem. Diretório vazio aqui é etapa
não começada, não lacuna esquecida.

## Regras — sempre

- **Falha se anuncia.** Chamada que falhou é falha reportada, nunca resultado
  plausível nem zero. Fonte fora do ar aparece como indisponível; fonte adiada,
  como não integrada. **Os dois estados são distintos e nenhum vira número.**
- **Não inventar problema.** Estando tudo saudável, dizer isso explicitamente.
  "Nada a reportar" é afirmação, não seção vazia.
- **Nunca imprimir token, header de autenticação ou URL de webhook.** URL de
  webhook **é** credencial: o segredo está embutido nela.
- **Nunca expor dado pessoal de usuário final.** Ticket entra no laudo só como
  `#id` + idade.
- **Observabilidade é leitura, sempre.** Helpdesk, APM e Langfuse só fazem `GET`
  — garantia por capacidade, não por política.
- **No board, só as quatro escritas da SPEC §6 — e só pelo wrapper.** Criar com
  a label injetada, comentar em issue que **tenha** a label, transicionar quando
  o PR abriu, liberar quando o PR foi aprovado. Todo o resto é proibido,
  inclusive editar campo. As ferramentas de MCP dessas operações ficam negadas
  de propósito: **operação permitida não é caminho permitido.**
- **No GitHub, o agente propõe e para.** Commit e push só em worktree isolado e
  branch `bugfix/<KEY>`, PR sempre contra a base configurada. Merge, fechar PR e
  alterar review são proibidos — e negados no harness. **CI verde é
  pré-condição, não autorização.**
- **Nenhum identificador de empresa, cliente ou sistema interno de terceiro
  entra neste repositório.** Verificado por `tests/casos/00-sanitizacao.sh`, que
  falha o CI. Ver
  [`docs/decisoes/0002-sanitizacao-verificada-por-teste.md`](docs/decisoes/0002-sanitizacao-verificada-por-teste.md).

O detalhamento e o *porquê* de cada uma estão na SPEC §6 e §9. A distinção entre
**regra** (não se ajusta sem decisão) e **calibragem** (limiar, se ajusta sem
cerimônia) está na SPEC §9.1 — e é por isso que todo limiar vive em
`.ai/politicas/`, e não literal em script.

## Testes

```bash
tests/run.sh                  # tudo, sem credencial nenhuma
tests/run.sh 00-sanitizacao   # um caso
```

**Mudança em `tools/` sem rodar a suíte é mudança não verificada.** Duas redes
que valem entender: o **golden file** pega alteração acidental no laudo; os
**testes de contrato** pegam violação de regra. Mudar o golden é ato deliberado
e o diff vai no commit — refatoração que exige mudar o golden mudou
comportamento e não é refatoração.

⚠️ `shellcheck` ausente faz a verificação estática **falhar**, não pular.
Verificação que se pula em silêncio é verificação que não existe.
