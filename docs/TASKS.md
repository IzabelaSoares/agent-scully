# Tasks — Agent Scully

Quebra do [`PLAN.md`](PLAN.md). Cada task tem **critério de pronto verificável**
e cabe num commit.

> **Por que só as três primeiras etapas estão detalhadas:** task escrita com seis
> etapas de antecedência é ficção. Ela envelhece antes de ser executada, e o
> custo de mantê-la atualizada é pago em cima de trabalho que talvez não
> aconteça daquele jeito. Cada etapa é detalhada quando começa; o que ela
> **entrega** e por que ela vem naquela ordem já está no `PLAN.md`, e é isso que
> precisa ser estável.

**Invariante do projeto, não negociado por nenhuma task abaixo:** o que roda
sozinho é **leitura**, e as escritas são as quatro da [`SPEC.md`](SPEC.md) §6,
cada uma por seu wrapper.

**Convenção de branch e PR:** `docs/*`, `feat/*`, `fix/*`, `ops/*` a partir de
`main`, PR sempre — inclusive para o autor. Merge é humano
([`SPEC.md`](SPEC.md) §9), e vale para a pessoa que escreveu o repositório.

---

## Etapa 0 — Contrato e rede de segurança

### A1. Esqueleto do repositório e licença

Estrutura de diretórios, `LICENSE` (MIT), `.gitignore` que exclui `.env` e
`.local/`.

**Pronto quando:** `git status` limpo com um `.env` presente na raiz; `.local/`
não aparece em `git ls-files`.

### A2. Fonte única em `.ai/` e os symlinks

`.ai/INSTRUCTIONS.md` como índice always-loaded; `CLAUDE.md` e `AGENTS.md` na
raiz e `.claude/commands`, `.claude/skills` como **symlinks**.

**Pronto quando:** `git ls-files -s` mostra modo `120000` nos quatro; editar
`.ai/INSTRUCTIONS.md` altera o conteúdo lido por `CLAUDE.md`; nenhum dos
symlinks tem conteúdo próprio.

### A3. A suíte roda sem credencial

`tests/run.sh` executa todos os casos de `tests/casos/`, soma asserções e sai
≠ 0 se qualquer uma falhar. Isolamento explícito do `.env` da máquina.

**Pronto quando:** `tests/run.sh` passa numa máquina sem `.env` **e** numa
máquina com `.env` preenchido, com o mesmo resultado; nenhum caso faz chamada de
rede.

### A4. Verificação estática

`shellcheck` em todo `*.sh`, sintaxe de todo `*.py`, e — importante — **falha
declarada quando a ferramenta não está instalada**.

**Pronto quando:** `shellcheck` ausente faz o caso **falhar**, não pular. Uma
verificação que se pula em silêncio é uma verificação que não existe: foi assim
que um defeito real sobreviveu semanas num projeto anterior.

### A5. Teste de sanitização

`tests/casos/00-sanitizacao.sh` varre o repositório rastreado contra uma lista
de identificadores proibidos — nome de empresa, domínio de instância, prefixo de
chave de issue de origem privada, id de entidade, nome de pessoa.

**Pronto quando:** inserir qualquer termo da lista em qualquer arquivo
rastreado faz o CI **falhar**; a lista vive em arquivo próprio e é ela mesma
verificada (uma lista vazia falha o caso); arquivo binário e o próprio arquivo
da lista são excluídos da varredura sem exceção silenciosa.

> **Por que teste e não revisão:** revisão humana não escala num repositório que
> vai crescer por meses, e o erro que ela deixa passar é irreversível — conteúdo
> publicado em repositório público fica em cache e em fork.
> Ver [`decisoes/0002-sanitizacao-verificada-por-teste.md`](decisoes/0002-sanitizacao-verificada-por-teste.md).

### A6. CI

Workflow que roda a suíte em `push` para `main` e em todo `pull_request`.
**Sem nenhum secret**, por construção: todo caso roda sobre `tests/fixtures/`.

**Pronto quando:** a run passa verde; `permissions:` é `contents: read`;
remover um secret inexistente não muda nada porque não há nenhum.

### A7. SPEC, plano, tasks e as primeiras decisões

**Pronto quando:** `SPEC.md`, `PLAN.md`, `TASKS.md`, `ROADMAP.md`, `ALVO.md` e
as quatro primeiras entradas de `decisoes/` existem; todo link interno resolve
(verificado por caso da suíte).

### A8. Templates de issue e de PR

**Pronto quando:** abrir issue oferece os tipos de bug e de melhoria com campos
obrigatórios de reprodução e resultado esperado; o template de PR pede a
evidência e o resultado da suíte.

> Os campos obrigatórios do template de bug não são burocracia: são exatamente
> as pré-condições que o veto de autonomia da Etapa 10 vai checar. Bug sem passo
> de reprodução e sem resultado esperado é bug que nenhum agente pode pegar — e
> pedir isso na entrada é mais barato que descobrir na triagem.

### A9. README

**Pronto quando:** responde, nesta ordem, o que é, por que Scully, **o que já
funciona e o que não**, e que o alvo é declaradamente fictício; nenhuma
afirmação sobre estado que a suíte não sustente.

---

## Etapa 1 — Ambiente e credenciais

### B1. Biblioteca de ambiente com precedência correta

`tools/lib/env.sh` carrega o `.env` **sem** sobrescrever variável já presente no
ambiente, e trata valor entre aspas.

**Pronto quando:** `CHAVE=injetada` no ambiente ganha do `.env`;
valor com `&`, `?` e espaço sobrevive; `SEM_ENV=1` ignora o arquivo por
completo. Os três com asserção própria.

**Por que é a primeira task da etapa:** sem ela, todo teste de "a fonte caiu"
escrito depois roda com a credencial boa do arquivo e passa por engano
([`SPEC.md`](SPEC.md) §10).

### B2. Inventário de credenciais

`.env.example` com, para cada variável: o que é, **em que conta**, quem emite,
qual escopo mínimo e qual a validade.

**Pronto quando:** cada variável tem as cinco informações; nenhum valor real
está no arquivo; um caso da suíte falha se `.env.example` deixar de citar
variável que algum script lê.

> A última asserção existe porque a divergência entre o que o script lê e o que o
> exemplo documenta é o defeito mais comum e o mais chato de diagnosticar: ele se
> manifesta como "funciona na sua máquina".

### B3. Verificação de credencial sem imprimir valor

`ops/verificar-credenciais.sh` confere cada credencial com uma chamada mínima e
reporta apenas ✅/❌ e o motivo.

**Pronto quando:** a saída não contém nenhum caractere de nenhum segredo, nem em
caso de erro; um caso da suíte grava um segredo sentinela no ambiente e falha se
ele aparecer na saída.

### B4. `PRIMEIRO-DIA.md`

Do clone à primeira ronda, em passos, **cada um provando uma coisa**.

**Pronto quando:** uma pessoa que nunca viu o repositório chega ao primeiro
laudo lendo só este arquivo — verificado por alguém que não o escreveu.

---

## Etapa 2 — Primeira fonte: o board

### C1. Política de prazo declarativa

`.ai/politicas/prazo.yaml`: por origem do bug, qual campo de prazo vale, em que
precedência, e o *fallback*. Com a razão de cada escolha ao lado.

**Pronto quando:** nenhum nome de campo de prazo aparece literal em script; o
arquivo é a única fonte; um caso da suíte falha quando o `.yaml` e a
documentação divergem.

### C2. Radar de prazo

`tools/coleta/board-radar.sh` devolve JSON normalizado — chave, prazo efetivo,
campo de origem do prazo, dias de atraso, classificação.

**Pronto quando:** a saída tem **só** os campos que o julgamento usa; a
classificação (🔴 estourado / 🟡 a estourar na janela) sai do `.yaml`; a data de
referência é injetável por variável, **sem a qual a classificação é intestável**.

### C3. Validação contra número calculado à mão

**Pronto quando:** sobre a mesma amostra, o radar reproduz o número conferido à
mão, e a conferência fica registrada no PR — não no histórico de conversa de
ninguém.

### C4. Retentativa e o estado de fonte caída

Duas novas tentativas em 5xx, 429 e timeout, com espera crescente; persistindo,
saída marcada como indisponível.

**Pronto quando:** um dublê que responde 500 três vezes produz saída marcada
`indisponivel: true` e **nunca** lista vazia; um dublê sem credencial produz
`nao_integrada: true`; os dois estados são distinguíveis na saída e nenhum é
zero.

---

## Etapas 3 a 12

Entrega e ordem estão no [`PLAN.md`](PLAN.md). Detalhadas quando começam — ver a
nota no topo deste arquivo.

| Etapa | Entrega | Estado |
|---|---|---|
| 3 | O laudo: template, golden, contrato, Slack | a detalhar |
| 4 | A ronda mora no Actions: cron, dispatch, guard de saída | a detalhar |
| 5 | O alvo existe: `meridian-assist` + carga versionada | a detalhar |
| 6 | Saúde do alvo (APM) | a detalhar |
| 7 | A camada de LLM (Langfuse), privacidade por capacidade | a detalhar |
| 8 | O helpdesk (sandbox) | a detalhar |
| 9 | Escrita estreita no board: os quatro wrappers | a detalhar |
| 10 | Fix agent, review interno e PR | a detalhar |
| 11 | Métricas de processo: o funil | a detalhar |
| 12 | Padrão sistêmico e o SLO do agente | a detalhar |
