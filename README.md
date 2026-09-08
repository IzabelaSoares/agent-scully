# Agent Scully

Agente de plantão para triagem de bugs. Faz a **ronda** das fontes de um serviço
em produção, produz um laudo verificável no Slack e mede o **processo** de bugs
que existe em volta dele — não só o estado.

Ele alimenta quem está de plantão. Não substitui.

> **Estado: Etapa 0 de 12** — contrato e rede de segurança. O que existe hoje é
> a especificação, a suíte de testes e o CI. **Nenhum coletor está
> implementado.** Este bloco é atualizado a cada etapa, e nenhuma afirmação de
> estado entra aqui sem teste que a sustente — é a regra da
> [SPEC §1](docs/SPEC.md), aplicada ao próprio README.

---

## Por que "Scully"

Mulder acredita; Scully verifica. A personagem é a cética do par: exige
evidência, faz a autópsia e assina o laudo com o que os dados sustentam — nem
mais, nem menos.

O nome nomeia o requisito mais difícil de um agente de LLM em plantão:
**recusar a saída plausível**. Um modelo a quem se pede o estado de um serviço
sempre consegue escrever um relatório bonito, inclusive quando não conseguiu ler
nada. Metade da especificação existe para tornar isso impossível por construção,
e não por boa vontade do prompt.

Daí a regra que atravessa o projeto: **falha se anuncia**. Fonte que caiu aparece
como caída; fonte não integrada aparece como lacuna; e **nenhum dos dois estados
vira zero**, porque zero se lê como "está tudo bem".

## A tese

Três observações sobre plantão de bug, e o que o agente faz com cada uma.

**1. Relatório de plantão mede estado, e o problema é de processo.**
"17 bugs parados, 8 com prazo estourado" gera pânico na segunda e indiferença na
quinta. Não diz *onde a fila engasga* — se o bug demora a ser triado, a ser
pego, a ser revisado, ou se volta depois de fechado.
→ O Scully publica **métricas do funil** ao lado do estado: tempo até triagem,
tempo em cada estado, idade do trabalho em curso, taxa de reabertura, taxa de
duplicata, vazão contra influxo. Em p50 e p90, **nunca média** — a distribuição
de idade de bug tem cauda longa, e é a cauda que interessa.

**2. O aprendizado não fecha o loop.** Cada armadilha de ferramenta custa horas
de alguém e, sem registro, custa as mesmas horas de novo. → Armadilha vira
entrada versionada com data e evidência; e **achado de review que se repete três
vezes graduou de julgamento para verificação estática** — vira `grep` e nunca
mais custa token nem atenção.

**3. Ninguém observa o observador.** Um agente que exige observabilidade de um
serviço e não publica a sua própria é um agente em que se confia por hábito.
→ O Scully é ele mesmo uma aplicação de LLM: instrumenta a si próprio com as
mesmas ferramentas com que vigia o alvo, e publica o seu SLO — execuções, falha
por fonte, custo, latência.

Nenhuma das três é ideia nova em engenharia. As três são raras em automação de
plantão, e é nelas que este repositório aposta.

## O modelo de permissão

O agente tem credencial de escrita em três sistemas. Ele é conduzido por um
modelo de linguagem, o que significa que **toda restrição expressa em prosa é
negociável**. Então nenhuma restrição que importa fica em prosa:

| Camada | Força | Exemplo |
|---|---|---|
| **Capacidade** — a ferramenta não sabe fazer o proibido | máxima | coletor só faz `GET`; o wrapper de liberação usa o endpoint de assignee, que não tem como tocar em outro campo |
| **Permissão** — o harness recusa a chamada | alta | lista explícita de ferramentas permitidas |
| **Rule** — arquivo de instrução | baixa | o que as outras não expressam, e o *porquê* de todas |

Três consequências que valem citar porque não são óbvias:

- **Allowlist, não denylist.** Lista de negação pressupõe uma pessoa como
  caso-padrão — chamada desconhecida abre prompt e alguém decide. Em job
  automático não existe esse alguém: **o que não estiver negado executa.**
- **Operação permitida não é caminho permitido.** As ferramentas de MCP
  equivalentes às escritas permitidas ficam **negadas**. A restrição real vive
  no wrapper; um caminho que não passa pelo wrapper é um caminho sem restrição.
- **CI verde é pré-condição, não autorização.** O gate distingue "sem check",
  "check rodando" e "check verde", e trata ausência de check como bloqueio.
  Ausência de sinal não é sinal bom. **Merge é sempre humano.**

Raciocínio completo em
[`docs/decisoes/0001`](docs/decisoes/0001-restricao-na-camada-mais-forte.md).

## O alvo é declaradamente fictício

O serviço vigiado é `meridian-assist`, um assistente de LLM para dúvidas sobre
políticas internas. **A empresa Meridian não existe.**

Isto está dito aqui, na SPEC e em [`docs/ALVO.md`](docs/ALVO.md) porque a
primeira pergunta de qualquer avaliador competente é "de onde vêm esses dados", e
a resposta precisa estar pronta antes da pergunta.

**O que é fictício é a empresa. O que é real é tudo o mais:** o serviço roda e
falha de verdade, é instrumentado, tem board de bug com fila de verdade, tem
repositório com CI, e o agente abre pull request de verdade contra ele. A carga
é sintética e o gerador é **versionado** — o que dá ao projeto uma propriedade
que um alvo real não daria: **quem clonar reproduz o comportamento do agente.**

## Arquitetura

```
.ai/                    fonte única de documentação e ferramental
  politicas/            limiar e regra como dado declarativo, versionado e testado
  tools/coleta/         coletores — só GET, devolvem JSON pequeno e normalizado
  tools/acoes/          as escritas, com a restrição embutida no wrapper
  templates/            formatos de saída; o agente preenche, não inventa
  skills/               procedimento sob demanda: recebe o JSON e julga
docs/                   SPEC, plano, tasks, roadmap e as decisões
tests/                  suíte que roda sem credencial nenhuma
```

Duas réguas explicam quase todo o layout:

**Se pode ser script, é script.** Escolha de campo de prazo, aritmética de data,
agrupamento, dedup e contagem não chamam modelo. O que sobra para o modelo é
julgamento: o que merece linha num laudo com cota fechada, como agrupar erro por
causa provável, se um bug tem descrição suficiente para alguém corrigir. Efeito
colateral que vale metade do projeto: **o que é script é testável sem
credencial, e por isso roda no CI a cada PR.**

**Limiar é dado, não código.** Nenhum número de calibragem aparece literal em
script. Ajustar prazo é diff de uma linha, revisável por quem entende do negócio
e não do bash —
[`docs/decisoes/0003`](docs/decisoes/0003-politica-de-sla-declarativa.md).

## Documentação

| Documento | O que responde |
|---|---|
| [`docs/SPEC.md`](docs/SPEC.md) | o que o agente é, o que garante e o que não faz |
| [`docs/PLAN.md`](docs/PLAN.md) | o que se constrói, em que ordem e **por quê** |
| [`docs/TASKS.md`](docs/TASKS.md) | as tasks da etapa em curso, com critério de pronto |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | horizontes depois do plano, e os **riscos abertos** |
| [`docs/ALVO.md`](docs/ALVO.md) | o que é fictício e o que é real, e por quê |
| [`docs/decisoes/`](docs/decisoes/README.md) | cada escolha, **com as alternativas descartadas e o motivo** |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | convenção de branch, commit e PR |

## Rodar a suíte

Sem credencial, sem rede, sem configuração:

```bash
git clone <este-repositorio> && cd agent-scully
sudo apt-get install -y shellcheck jq   # shellcheck ausente FALHA a suíte, não pula
tests/run.sh
tests/run.sh 00-sanitizacao             # um caso só
```

É a mesma invocação que o CI faz. Não há caminho alternativo, e não há secret
envolvido — por construção, e não por sorte.

## Licença

[MIT](LICENSE).
