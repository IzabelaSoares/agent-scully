# Plano — Agent Scully

O que se constrói, **em que ordem e por quê**. A ordem é por dependência e por
risco, não por tamanho: cada etapa entrega algo exercível, testado e publicado.

O *quê* está na [`SPEC.md`](SPEC.md); as tasks, em [`TASKS.md`](TASKS.md); os
horizontes que ainda não são plano, em [`ROADMAP.md`](ROADMAP.md).

Escrito em 08/09/2026.

---

## Três lições que o plano herda

Não são preferência de estilo. Cada uma custou retrabalho num projeto anterior
de mesma natureza, e cada uma muda a ordem das etapas abaixo.

**1. Decidir o hospedeiro antes de construir mecânica de hospedagem.**
No projeto anterior, o agendamento local — timer, rodízio de máquina, suplência
— foi construído, testado e depois descartado inteiro quando ficou claro que o
lugar certo era o CI. A mecânica não estava errada; estava no lugar errado, e
descobrir isso depois custou o trabalho todo.
→ **Consequência:** a ronda vai para o GitHub Actions na **Etapa 4**, assim que
tem algo a postar, e nunca existe versão local que precise ser desmontada. O que
roda na máquina de alguém é a suíte de testes e o desenvolvimento.

**2. Estado não pode depender do disco do hospedeiro.**
Runner de CI não tem persistência entre execuções. Todo estado que atravessa
execuções — marca d'água, registro de custo, veredito — nasce com formato que
sobrevive à mudança de lugar. `.local/` é o lugar hoje, não o contrato.
→ **Consequência:** aparece como requisito na Etapa 4, não como refatoração
depois.

**3. Allowlist, não denylist.**
Lista de negação pressupõe uma pessoa como caso-padrão: chamada desconhecida
abre prompt e alguém decide. Em job automático não existe esse alguém — **o que
não estiver negado executa.**
→ **Consequência:** a execução passa `--allowedTools` explícito desde a primeira
etapa que chama modelo, e o `deny` é segunda linha, não a primeira.

## O que ordena as etapas

1. **A rede de segurança vem antes do que ela protege.** Suíte, CI e teste de
   sanitização são a Etapa 0 — não porque testar é virtuoso, mas porque este é
   um repositório público derivado de trabalho privado, e a verificação de
   sanitização precisa existir antes do conteúdo que ela verifica.
2. **Fechar o contrato de saída cedo, com uma fonte só.** O laudo ganha
   template, golden file e teste de contrato quando existe **uma** fonte. Feito
   depois, cada fonte nova negocia o formato e o formato perde.
3. **Leitura antes de escrita.** Uma fonte por vez, cada uma validada contra
   número calculado à mão.
4. **O que depende de histórico vem depois de haver histórico.** Métrica de
   funil sobre três dias de board é ruído com casas decimais.

---

## Etapa 0 — Contrato e rede de segurança

**Entrega:** SPEC, plano, tasks, decisões; estrutura `.ai/`; suíte que roda sem
credencial; CI verde; teste de sanitização; templates de issue e PR.

**Por que primeiro:** a suíte tem que existir antes do que ela testa, e o teste
de sanitização antes do conteúdo que ele verifica. O CI verde no primeiro commit
não é cerimônia — é a prova de que a rede está armada e que o próximo PR tem
como falhar.

**Rede contra o risco desta etapa:** o risco é vazar identificador de origem
privada. Ele é atacado por **capacidade**: `tests/casos/00-sanitizacao.sh` varre
o repositório inteiro contra uma lista proibida e falha o CI. Cuidado humano não
escala num repositório que vai crescer por meses.

## Etapa 1 — Ambiente e credenciais

**Entrega:** biblioteca de ambiente com **precedência do ambiente sobre o
arquivo**; `.env.example` completo, com conta, emissor e validade de cada
credencial; verificação que confere cada credencial **sem imprimir valor**;
`PRIMEIRO-DIA.md`.

**Por que agora:** a armadilha do `set -a; source` (SPEC §10) torna o caminho de
falha intestável. Sem resolver isso na Etapa 1, todo teste de "fonte caiu"
escrito depois é teste que mente — ele roda com a credencial boa do arquivo.

**Verificável:** `TOKEN=invalido tools/coleta/... ` falha. Hoje, num script
ingênuo, passa.

## Etapa 2 — Primeira fonte: o board

**Entrega:** radar de prazo (`coleta/board-radar.sh`) e a **política de prazo
declarativa** (`.ai/politicas/prazo.yaml`), com teste que falha se código e
documentação divergirem.

**Por que o board primeiro:** é a única fonte que não depende do alvo existir, e
é onde mora a maior parte do valor. E é a fonte que ensina a lição da política
declarativa: no mundo real, campo de prazo é bagunça — legado, herdado,
preenchido pela metade, com semântica diferente por origem do bug. Um agente que
codifica a regra de prazo em `if` é um agente que não sobrevive ao primeiro
board diferente do seu. Ver
[`decisoes/0003-politica-de-sla-declarativa.md`](decisoes/0003-politica-de-sla-declarativa.md).

**Validação:** o número que o radar produz é conferido à mão sobre a mesma
amostra. Coletor que ninguém conferiu é coletor que ninguém sabe se funciona.

## Etapa 3 — O laudo

**Entrega:** `templates/laudo.md`, gerador, **golden file** e **teste de
contrato**; postagem no Slack por wrapper que confere o status da resposta; e a
escala como dado (`politicas/escala.yaml`), que é o que põe o nome de quem está
de plantão no cabeçalho.

**Por que com uma fonte só:** ver o item 2 de "o que ordena as etapas". As duas
redes fazem coisas diferentes e as duas importam:

- **golden file** pega mudança acidental no payload
- **contrato** pega violação de regra: diagnóstico vazando para o texto, fonte
  fora do ar virando zero, fonte adiada confundida com fonte caída, seção vazia
  em vez de "nada a reportar"

Mudar o golden é ato deliberado, e o diff vai no commit. **Refatoração que exige
mudar o golden mudou comportamento e não é refatoração.**

## Etapa 4 — A ronda mora no Actions

**Entrega:** workflow de cron para as duas rondas, `workflow_dispatch` para
disparo manual, secrets de repositório, e o **guard de saída** — validar que a
saída começa com o cabeçalho esperado antes de arquivar, e sair ≠ 0 quando não
começa.

**Por que aqui e não no fim:** lição 1. Assim que existe algo a postar, o lugar
de postar é decidido — e nenhuma linha de agendamento local chega a ser escrita.

**Por que o guard é desta etapa:** é a etapa em que a execução passa a ser
automática, e a armadilha do status 0 em erro de API (SPEC §10) é exatamente uma
falha silenciosa num job que roda todo dia. O guard entra junto com o cron, não
depois do primeiro laudo falso.

**Entra aqui também:** estado com formato portável (lição 2) e `--allowedTools`
explícito (lição 3).

## Etapa 5 — O alvo existe

**Entrega:** `meridian-assist` — serviço mínimo, plausível e **declaradamente
fictício** (SPEC §5.1) —, instrumentado, com **gerador de carga versionado**;
repositório próprio, com CI e convenção de branch.

**Por que agora:** as duas etapas seguintes não têm o que observar sem ele. E ele
é pré-requisito do fix agent: correção por PR exige um repositório alvo que não
seja este.

**Por que a carga é versionada:** é o que torna o comportamento do agente
**reproduzível por quem clonar**. Um alvo real não daria essa propriedade — e,
num portfólio, reprodutibilidade vale mais que autenticidade de tráfego.

## Etapa 6 — Saúde do alvo

**Entrega:** `coleta/apm.sh` — saúde no cabeçalho e erro agrupado na seção de
produção; limiares em `.ai/politicas/saude.yaml`.

**As duas armadilhas que esta etapa tem que provar resolvidas:** ⚪ para
zero-tráfego, e a frase que explica por que 🟢 conviveu com dezenas de erros de
log na mesma janela (SPEC §7). Sem as duas, esta etapa entrega um número que
convida a pular a seção que tem o problema.

## Etapa 7 — A camada de LLM

**Entrega:** `coleta/langfuse.sh` — erro de tool e de modelo que não derruba
requisição.

**Privacidade por capacidade, não por regra:** o coletor **não seleciona**
`input`, `output` nem `metadata`, e trunca a assinatura do erro antes de
qualquer eco de payload. Testado com fixture que contém conversa e assertiva que
falha se qualquer trecho dela aparecer na saída.

## Etapa 8 — O helpdesk

**Entrega:** `coleta/helpdesk.sh` — ticket preso com o bot vs. transbordado para
fila humana, com a regra de privacidade da SPEC §9 aplicada por capacidade: o
coletor não seleciona assunto.

## Etapa 9 — Escrita estreita no board

**Entrega:** os quatro wrappers de `tools/acoes/`, cada um com a restrição
embutida: label injetada na criação, recusa em issue sem a label, transição só
com PR aberto e verificado, liberação pelo endpoint de assignee.
**Dedup antes de criar**, e teto por execução.

**Por que depois de tudo o que lê:** SPEC §6. E porque o teto e a dedup são
mecanismos contra problemas diferentes (SPEC §9.1) — construir os dois juntos é
o que impede o agente de criar a mesma issue três vezes e parar por limite.

**Rede contra o risco desta etapa:** dublê que registra as requisições
recebidas. É como se prova que uma recusa por regra **não emitiu chamada**, o
que asserção sobre código de saída não prova.

## Etapa 10 — Fix agent, review interno e PR

**Entrega:** worktree isolado, correção mínima, teste do alvo, **review interno
por agente independente** antes do PR, abertura de PR, gate de CI que distingue
"sem check" de "verde", e poda de worktree morto.

**Por que o review interno é independente e não corrige:** o autor é o pior
revisor do que acabou de escrever, e um revisor que pode editar é o mesmo agente
com passos extras — a independência evapora. Ele classifica em
`ok` / `ressalva` / `bloqueia` e **só reporta**. Tem direito explícito de dizer
"nada a apontar": revisor que sempre acha algo é revisor que ninguém lê.

**A regra de evolução:** achado que se repete três vezes **graduou** de
julgamento para verificação estática — vira `grep` e nunca mais custa token.

## Etapa 11 — Métricas de processo

**Entrega:** `coleta/board-funil.sh` e a seção de funil no laudo — tempo até
triagem, tempo por estado, idade do trabalho em curso, reabertura, duplicata,
vazão vs. influxo. **p50 e p90, nunca média** (SPEC §8.1).

**Por que só aqui:** exige histórico. Funil calculado sobre três dias de board é
ruído com casas decimais, e publicar ruído com casas decimais é como se perde a
credibilidade de um painel.

**Por que é a etapa que justifica o projeto:** é onde o agente deixa de contar
bug e passa a medir o processo que produz bug. As dez etapas anteriores são o
encanamento que torna esta possível.

## Etapa 12 — Padrão sistêmico e o SLO do agente

**Entrega:** agrupamento do influxo por área e por assinatura, com sugestão de
ação de processo acima do limiar (SPEC §8.2); e o SLO do próprio agente
publicado — execuções, falha por fonte, custo, latência (SPEC §8.3).

**Por que fecham juntas:** são as duas metades da mesma ideia. Uma olha o
processo do time com os dados que o agente coletou; a outra olha o processo do
agente com os mesmos instrumentos. Um agente que exige observabilidade e não
publica a sua própria é um agente em que se confia por hábito.

---

## O que fica fora do plano, e por quê

**Alerta em tempo real.** Ronda não é monitoramento (SPEC §3). Quem acorda
alguém às 3h tem outra latência e outra garantia; confundir os dois entrega o
pior dos dois.

**Merge automático por CI verde.** CI verde é pré-condição, não autorização
(SPEC §6). E é a regra que não se relaxa "só nesse caso": a primeira exceção é o
fim da garantia.

**Adaptador para outros boards.** Tentador — e é como se constrói abstração
sobre um caso só. A política de prazo declarativa (Etapa 2) já isola a parte que
de fato varia entre boards; o resto espera o segundo board de verdade.

**Substituir a pessoa de plantão.** Ver SPEC §1.
