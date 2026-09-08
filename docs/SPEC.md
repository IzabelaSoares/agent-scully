# Spec — Agent Scully

O que o agente é, o que ele garante e o que ele **não** faz. É a referência da
qual saem o plano e as tasks: quando a implementação divergir daqui, um dos dois
está errado, e a divergência se resolve — não se ignora.

Ordem de execução: [`PLAN.md`](PLAN.md) · Tasks: [`TASKS.md`](TASKS.md) ·
Horizontes: [`ROADMAP.md`](ROADMAP.md) · Decisões: [`decisoes/`](decisoes/)

Versão 1 — 08/09/2026.

---

## 1. Propósito e papel

O Agent Scully faz a **ronda** das fontes de um serviço em produção, produz um
laudo verificável e mede o processo de bugs que existe em volta dele.

Ele **alimenta** quem está de plantão. Não substitui.

Três consequências que valem para tudo o que vem abaixo:

- **Saída incompleta é tolerável.** Uma fonte ainda não integrada não invalida o
  laudo; existe uma pessoa no caminho que sabe o que falta.
- **Falha silenciosa não é tolerável.** Se uma fonte cai, o laudo diz que caiu.
  Silêncio precisa significar "não havia nada", nunca "não consegui olhar" — é a
  diferença entre saúde e cegueira.
- **O agente não decide, levanta.** Onde ele opina, opina explicitamente como
  sugestão, e diz em que evidência se apoia.

### Por que "Scully"

Mulder acredita; Scully verifica. A personagem é a cética do par: exige
evidência, faz a autópsia e assina o laudo com o que os dados sustentam — nem
mais, nem menos.

O nome não é decoração. Ele nomeia o requisito mais difícil de um agente de
LLM em plantão: **recusar a saída plausível**. Um modelo pedindo para relatar o
estado de um serviço sempre consegue escrever um relatório bonito, inclusive
quando não conseguiu ler nada. Toda a §7 e toda a §9 existem para tornar isso
impossível por construção, e não por boa vontade do prompt.

### Por que um agente de LLM, e não um cron com `curl`

Pergunta legítima, e a resposta honesta tem duas partes.

**Contar bug é `curl` + `jq`, e é assim que está implementado.** Tudo que é
determinístico vive em `.ai/tools/` e não chama modelo nenhum: escolha de campo
de prazo, aritmética de data, agrupamento, dedup, contagem. Ver a regra do
`tools/` na §4.

**O que sobra para o modelo é o julgamento**, e é pouco de propósito: decidir o
que merece linha num laudo com cota fechada, agrupar erro por causa provável,
correlacionar um pico com um deploy, julgar se um bug tem descrição suficiente
para alguém corrigir. Nada disso é consulta; tudo isso é leitura de contexto.

A régua que separa os dois está na §4 — **se pode ser script, é script** — e ela
tem um efeito colateral que é metade do valor do projeto: o que é script é
testável sem credencial, e por isso roda no CI a cada PR.

## 2. A tese

Três observações sobre plantão de bug, e o que o agente faz com cada uma.

**1. Relatório de plantão mede estado, e o problema é de processo.**
"17 bugs parados, 8 com prazo estourado" é um número que gera pânico na segunda
e indiferença na quinta. Ele não diz *onde a fila engasga* — se o bug demora a
ser triado, se demora a ser pego, se demora a ser revisado, ou se volta.
O Scully publica **métricas do funil** ao lado do estado (§8): tempo até
triagem, tempo em cada estado, idade do trabalho em curso, taxa de reabertura,
taxa de duplicata. Estado convida a apagar incêndio; processo convida a mudar o
processo.

**2. O aprendizado não fecha o loop.** Toda armadilha da §10 custou horas de
alguém, e sem registro custa as mesmas horas de novo. Duas mecânicas atacam
isso: armadilha vira entrada versionada com data e evidência, e **achado de
review que se repete três vezes graduou de julgamento para verificação
estática** — vira `grep` e nunca mais custa token nem atenção.

**3. Ninguém observa o observador.** Um agente que exige observabilidade de um
serviço e não publica a sua própria é um agente em que se confia por hábito.
O Scully é, ele mesmo, uma aplicação de LLM: tem latência, custo, taxa de erro
e dependência externa. Ele instrumenta a si mesmo com as mesmas ferramentas com
que vigia o alvo, e publica o seu próprio SLO (§8.3).

Nenhuma das três é ideia nova em engenharia. As três são raras em automação de
plantão, e é nelas que este repositório aposta.

## 3. Escopo

**Dentro:** a ronda matinal e a ronda de fecho, dias úteis; as fontes de leitura
da §5; o laudo no Slack; as métricas de processo da §8; as escritas estreitas da
§6 no board; e a proposta de correção por pull request no repositório do alvo.

**Fora, e por decisão:**

- **Merge.** Nunca. Ver §9.
- **Escrita em base de conhecimento.** O agente lê a escala e a documentação do
  alvo; não escreve nelas.
- **Substituir a pessoa de plantão.** Ver §1 — muda o padrão de qualidade
  exigido, não só o texto do laudo.
- **Alerta em tempo real.** O Scully faz ronda, não monitoramento. Quem acorda
  alguém às 3h é a stack de alerta do alvo, que tem outra latência e outra
  garantia. Confundir os dois entrega o pior dos dois.

## 4. Estrutura

`.ai/` é a fonte única de documentação e ferramental para agentes. `CLAUDE.md` e
`AGENTS.md` na raiz são symlinks para `.ai/INSTRUCTIONS.md`; `.claude/commands` e
`.claude/skills` apontam para os diretórios correspondentes. O critério de onde
vai cada arquivo novo está em [`.ai/CONVENTIONS.md`](../.ai/CONVENTIONS.md).

A divisão que importa:

| Diretório | Contém | Critério |
|---|---|---|
| `docs/` | referência descritiva | descreve, não manda |
| `rules/` | padrões acionáveis | manda, lido sob demanda |
| `politicas/` | limiar e regra como **dado** | versionado, testado, sem código |
| `tools/` | scripts determinísticos | **se pode ser script, é script** |
| `templates/` | formatos de saída | o agente preenche, não inventa |
| `skills/` | procedimento sob demanda | recebe o JSON e julga |
| `commands/` | janela + composição | ponto de entrada |

**Regra do `tools/`:** todo coletor devolve JSON pequeno e normalizado, só com os
campos que o julgamento usa. O ganho de contexto não vem de ser script — vem de
**moldar a saída**. Um `curl` que despeja 100 issues cruas é pior que uma
ferramenta de MCP bem escolhida.

**Regra do `politicas/`:** limiar não vira literal em script nem prosa em
documento. Vira arquivo declarativo, com a razão ao lado e um teste que falha
quando código e documentação divergem. O motivo está na §9.1 e em
[`decisoes/0003-politica-de-sla-declarativa.md`](decisoes/0003-politica-de-sla-declarativa.md).

**`.local/` é lugar, não contrato.** Todo estado que atravessa execuções — marca
d'água, registro de custo, veredito — nasce com formato que sobrevive à mudança
de hospedeiro: JSON pequeno, com carimbo próprio, num caminho configurável por
variável. Um runner de CI não tem persistência entre execuções, e descobrir isso
depois custa reescrever.

## 5. O alvo, e as fontes

### 5.1 O alvo é de demonstração, e isso está declarado

O serviço vigiado é **`meridian-assist`**: um assistente de LLM que responde
dúvidas de colaboradores sobre políticas internas, abre ticket quando não
resolve e escala para fila humana. A empresa **Meridian** não existe.

Isto está escrito aqui, no README e em
[`ALVO.md`](ALVO.md) porque um portfólio que finge ter tráfego de cliente real
não vale nada: a primeira pergunta de qualquer avaliador competente é "de onde
vêm esses dados", e a resposta precisa estar pronta antes da pergunta.

**O que é fictício é a empresa. O que é real é tudo o mais:** o serviço roda, é
instrumentado, gera erro de verdade, tem board de bug com fila de verdade, tem
repositório com CI de verdade, e o agente abre pull request de verdade contra
ele. A carga é sintética e o gerador de carga é versionado — o que torna o
comportamento do agente **reproduzível por quem clonar**, propriedade que um
alvo real não teria.

### 5.2 As fontes

| Fonte | Papel | Acesso | Ferramenta |
|---|---|---|---|
| **Jira** — radar de prazo | bug parado com prazo em risco | leitura | `coleta/board-radar.sh` |
| **Jira** — triagem | o que entrou desde a última ronda | leitura | `coleta/board-novos.sh` |
| **Jira** — similares | busca antes de criar bug (dedup) | leitura | `coleta/board-similar.sh` |
| **Jira** — funil | tempo em cada estado, reabertura, duplicata | leitura | `coleta/board-funil.sh` |
| **Jira** — as escritas | criar, comentar, transicionar, liberar | escrita | `acoes/board-*.sh` |
| **Helpdesk** (sandbox) | ticket preso com o bot vs. transbordado | leitura | `coleta/helpdesk.sh` |
| **APM** (tier free) | saúde do serviço e erro agrupado | leitura | `coleta/apm.sh` |
| **Langfuse** (tier free) | erro de tool e de modelo que não derruba requisição | leitura | `coleta/langfuse.sh` |
| **Escala** | quem está de plantão | dado versionado | `.ai/politicas/escala.yaml` |
| **Slack** | o laudo | escrita | `acoes/laudo-postar.sh` |
| **GitHub** | worktree, PR, estado de check | escrita | `acoes/gh-*.sh` + `coleta/gh-pr-estado.sh` |

**Helpdesk, APM e Langfuse são observabilidade: leitura sempre, sem exceção.** A
garantia é por **capacidade** — os coletores só sabem fazer `GET` —, não por
política. Ver §6.

**A escala é dado, não fonte.** Num time ela é uma página que qualquer pessoa
edita pelo navegador; num projeto solo é um arquivo versionado. **O que muda é
onde ela mora, não o que o laudo faz com ela** — e é por isso que ela entra como
política, e não como coletor com credencial. Não existe gesto de "assumir o
plantão": o nome sai da escala, e o engajamento se infere do trabalho que a
pessoa já deixa nos sistemas que o agente já lê.

**Por que Langfuse não é redundante com o APM:** erro de tool e alucinação de
formato não derrubam a requisição. O APM vê 200 e o helpdesk vê um ticket que o
bot "respondeu". A camada de LLM é a única que enxerga a resposta errada
entregue com sucesso.

⚠️ **Langfuse é também a fonte de maior risco de privacidade.** A `observation`
traz `input`, `output` e `metadata` — que é a conversa. O coletor **não os
seleciona**, e a assinatura do erro é truncada antes de qualquer eco de payload:
um erro de validação de schema embute os argumentos recebidos. A contagem sai do
total das listagens, o que dispensa a API de métricas.

## 6. Modelo de permissão

Cada restrição vai na **camada mais forte que a suporta**. Uma rule descreve
intenção e pode ser contornada por um modelo suficientemente criativo; só o
harness aplica.

| Camada | Força | Onde |
|---|---|---|
| **Capacidade** — a ferramenta não sabe fazer o proibido | máxima | `tools/coleta/*` só fazem `GET`; o wrapper de liberação usa o endpoint de assignee, que não sabe tocar em outro campo |
| **Permissão** — o harness recusa a chamada | alta | `--allowedTools` explícito; `deny` em `settings.json` |
| **Rule** — arquivo em `rules/` | baixa | o que as outras duas não expressam, e o *porquê* de todas |

⚠️ **Allowlist, não denylist.** Uma lista de negação é um anteparo atrás de uma
pessoa: chamada desconhecida abre prompt e alguém decide. **Num job automático
não existe esse alguém — o que não estiver negado executa.** A execução passa
`--allowedTools` explícito, e é esse o padrão a estender. O `deny` continua, como
segunda linha e como documentação do que é proibido de propósito.

### As quatro escritas no board, e nada mais

1. **Criar** issue de bug, com a label do agente **injetada pelo wrapper** —
   não pelo modelo.
2. **Comentar** em issue que **tenha** a label. Issue sem a label é issue de
   gente, e o agente não escreve nela.
3. **Transicionar** para "em revisão" **e só quando o PR abriu com sucesso**. A
   transição relata um fato verificado, nunca uma intenção.
4. **Liberar** — mover para validação e **retirar o assignee** — quando o PR foi
   aprovado e a branch não está atrás da base.

Todo o resto é proibido, **inclusive editar campo**: o agente não muda
prioridade, não reatribui e não reescreve descrição. A retirada de assignee da
quarta escrita usa o endpoint dedicado (`PUT .../assignee`), separado do de
edição de campo — o wrapper tem capacidade de anular assignee e capacidade
**nenhuma** de tocar em prioridade, resumo ou qualquer outro campo. Isso é o que
faz a quarta escrita não enfraquecer o modelo: muda o que é permitido, não a
força com que se aplica.

**A granularidade "só com a label" não se expressa em configuração de harness.**
Vira wrapper em `tools/acoes/`, que injeta a label na criação e **recusa** a
operação quando a issue não a tem. Estrutural em vez de exortativo.

⚠️ **As ferramentas de MCP equivalentes a essas quatro operações ficam
negadas.** Não é redundância: **operação permitida não é caminho permitido.** A
restrição vive no wrapper, então um caminho que não passa pelo wrapper é um
caminho sem restrição.

### No GitHub, o agente propõe e para

Commit e push **apenas** em worktree isolado e branch `bugfix/<KEY>`, PR sempre
contra a base configurada. Merge, fechar PR, resolver conversation, force-push e
alterar status de review são proibidos — e negados no harness.

**CI verde é pré-condição, não autorização.** O gate distingue três estados —
sem check, check rodando, check verde — e trata "sem check" como bloqueio, nunca
como aprovação. Ausência de sinal não é sinal bom.

## 7. Contrato de saída

O laudo é uma mensagem de Slack com teto de linhas. Cabeçalho com saúde do
serviço, plantonista e janela; seções por fonte; rodapé com custo e
autodiagnóstico. Esqueleto e cota em `.ai/templates/laudo.md` — 🚧 Etapa 3.

**Saúde no título.** Taxa de erro de requisição na janela: 🟢 abaixo do limiar
verde, 🟡 até o limiar amarelo, 🔴 acima, ⚪ **sem tráfego ou não verificado**.
Os limiares são calibragem e vivem em `.ai/politicas/saude.yaml`.

⚠️ **Verde não significa zero erro, e isso precisa estar dito no laudo.** A
saúde mede falha de *requisição*; a seção de produção conta *log* de erro. Um
serviço pode marcar 🟢 com 0% de falha e dezenas de erros na mesma janela —
falha em chamada externa que não derruba a requisição. Sem essa frase, o verde
convida a pular exatamente a seção que tem o problema.

⚠️ **Sem tráfego não é saúde.** Zero requisição dá taxa de erro zero e cairia em
🟢. O gerador trata o caso como ⚪ — que de madrugada é normal e em horário
comercial é incidente.

**Nada de diagnóstico no laudo.** Código HTTP, contagem de itens retornados e
nome de campo são log da execução, não conteúdo. Falha de coleta vira
`(fonte indisponível no momento)`, nunca um status code na mensagem.

**Fonte caída e fonte adiada são estados diferentes, e o laudo distingue os
dois.** ⚠️ `indisponível no momento` = falhou nesta execução, exige atenção.
🚧 `ainda não integrada` = lacuna conhecida e planejada, em cor neutra. Usar o
mesmo aviso para os dois é erro de projeto: um ⚠️ que aparece todo dia por
semanas treina o time a ignorá-lo — e é o mesmo símbolo que precisa funcionar no
dia em que uma fonte cair de verdade. **Nenhum dos dois estados vira número.**

**Retentativa:** 2 novas tentativas em erro transitório (5xx, 429, timeout), com
espera crescente. Persistindo, o laudo sai assim mesmo com a seção marcada.
Nunca omitir em silêncio.

**"Nada a reportar" é uma afirmação, não uma ausência.** O laudo diz "prazos sob
controle", não deixa a seção vazia. Ausência de texto é indistinguível de
ausência de coleta, e a §1 proíbe essa ambiguidade.

**Ordenação e cota.** Quando há mais alerta do que linha, o excedente entra numa
linha própria **que nomeia o grupo** — nunca um "e outros 12" que esconde de
que grupo se trata.

## 8. Métricas de processo

A parte que o estado não conta. Todas saem do histórico de mudança de status do
board, por script, sem modelo.

### 8.1 O funil

| Métrica | Pergunta que responde |
|---|---|
| **Tempo até triagem** | quanto um bug espera para alguém decidir o que é |
| **Tempo em cada estado** | onde a fila engasga — triagem, espera, correção, revisão |
| **Idade do trabalho em curso** | há quanto tempo o item mais velho está "em andamento" |
| **Taxa de reabertura** | quanto do que fecha volta — mede qualidade do fix, não velocidade |
| **Taxa de duplicata** | quanto do influxo é o mesmo problema chegando de novo |
| **Vazão vs. influxo** | a fila está crescendo ou drenando |

⚠️ **Percentil, nunca média.** A média de tempo de triagem com um bug de 180
dias e nove de um dia é 19 dias, número que não descreve nenhum dos dez. O laudo
publica p50 e p90 e a contagem — e quando a amostra é pequena demais para
percentil ter sentido, publica a amostra crua e diz que é pequena.

⚠️ **Nenhuma destas métricas é meta.** São instrumento de diagnóstico. Métrica
de processo que virou meta vira alvo de otimização, e otimizar tempo de triagem
é trivialmente alcançável triando errado. Isso está em
[`decisoes/0004-metrica-de-processo-nao-e-meta.md`](decisoes/0004-metrica-de-processo-nao-e-meta.md).

### 8.2 Padrão sistêmico

Bug isolado pede correção; bug repetido pede mudança de processo. O agente
agrupa o influxo da janela por área do código tocada e por assinatura de erro,
e **quando um grupo passa o limiar, sugere ação de processo** — teste que
faltava, validação na borda, documentação — em vez de mais uma linha de bug.

A sugestão é explicitamente sugestão, e vem com os itens que a sustentam. Ver
§1: o agente levanta, não decide.

### 8.3 O SLO do próprio agente

Publicado no rodapé do laudo e num painel:

- execuções concluídas / esperadas na janela
- falha por fonte, nomeada
- custo por execução (token e varredura), com ausência de dado como `—`, nunca `0`
- latência da ronda

**Isto não é vaidade de métrica.** É o que permite responder "o laudo de ontem
está confiável?" sem abrir o log — e é o que torna a §1 auditável em vez de
prometida.

## 9. Regras inegociáveis

Especificação de segurança, não preferência de estilo.

- **pt-BR, técnico e direto.** Nome de arquivo e título H1 em inglês.
- **Nunca imprimir token, header de autenticação ou URL de webhook.** A URL de
  webhook **é** credencial: o segredo está embutido nela.
- **Nunca expor dado pessoal de usuário final.** Ticket entra no laudo só como
  `#id` + idade. Assunto de ticket de helpdesk costuma conter nome de pessoa, e
  a regra vale literal.
- **Helpdesk, APM e Langfuse: somente leitura, sempre.**
- **No board, só as quatro escritas da §6.** Nenhuma outra, inclusive editar
  campo. Radar, triagem, funil e busca de similares são leitura.
- **Git:** commit e push apenas em worktree isolado e branch `bugfix/<KEY>`.
  Nunca na base, nunca fora do worktree. **Merge é sempre humano.**
- **GitHub:** nunca fazer merge, fechar PR, resolver conversation, force-push ou
  alterar status de review.
- **Falha se anuncia.** Chamada que falhou é falha reportada, nunca resultado
  plausível nem zero.
- **Não inventar problema.** Estando tudo saudável, dizer isso explicitamente.
- **Nenhum identificador de empresa, cliente ou sistema interno de terceiro
  entra neste repositório.** Não é etiqueta: é verificado por
  `tests/casos/00-sanitizacao.sh`, que falha o CI. Camada de capacidade, não de
  cuidado — ver
  [`decisoes/0002-sanitizacao-verificada-por-teste.md`](decisoes/0002-sanitizacao-verificada-por-teste.md).

### 9.1 Calibragem não é regra

Distinção que importa para não confundir as duas coisas ao ler a seção acima.

**Regra** é o que não se ajusta sem decisão explícita e registrada: não expor
dado de usuário, não escrever fora das quatro operações, não tocar na base,
merge humano.

**Calibragem** é limiar: os cortes de saúde, a janela do amarelo, a cota de
linhas, o teto de issues por execução, o limiar de padrão sistêmico. Existe
**para ser ajustada** quando a prática mostrar que está errada, e ajustar não é
violar a spec.

Por isso todo limiar mora em `.ai/politicas/`, em arquivo declarativo, com a
razão ao lado. É o que permite escolher número razoável agora em vez de tentar
acertar de primeira — e é o que torna o ajuste um diff de uma linha, revisável
por PR, em vez de uma caçada por literal espalhado em script.

⚠️ **O que o teto numérico não é: dedup.** Cota cumprida não é duplicata
evitada. São mecanismos diferentes contra problemas diferentes, e confundi-los
produz um agente que cria a mesma issue três vezes e para por limite.

## 10. Armadilhas conhecidas

Cada entrada tem data e evidência. **Sem a evidência, a próxima pessoa desfaz.**

As primeiras não foram descobertas aqui: são herança de um projeto anterior de
mesma natureza, registradas antes de custarem horas de novo. Estão marcadas
como *herdada*.

- **`set -a; source .env` faz o arquivo ganhar do ambiente** *(herdada)*.
  `TOKEN=invalido ./script` é silenciosamente ignorado e o script roda com a
  credencial do arquivo. Duas consequências: o caminho de falha fica
  **intestável**, e segredo injetado por variável (CI, export manual) é
  descartado sem aviso. Todo script usa a biblioteca de ambiente, que dá
  precedência ao ambiente.
- **`&` no `.env` quebra o `source`** *(herdada)*. URL de webhook contém
  `?key=...&token=...`; sem aspas, o bash lê o `&` como separador de job em
  background e a variável nunca chega ao script. Todo valor com `&`, `?` ou
  espaço vai entre **aspas simples**.
- **Filtro no cliente é case-sensitive; a linguagem de busca do board não é**
  *(herdada)*. Uma label que convive em duas grafias é achada pela busca e
  perdida pelo `jq`. Normalizar o caso em toda comparação de label.
- **`claude -p` sai com código 0 mesmo em erro de API** *(herdada)*. Um
  `API Error: 529` é devolvido como *saída* da execução, com status 0. Isso
  atravessa o `set -euo pipefail`, o `tee` grava o texto do erro como se fosse o
  laudo, e o script loga "resultado salvo". **É a falha silenciosa que a §1
  proíbe, no job que roda todo dia.** Exige guard explícito: validar que a saída
  começa com o cabeçalho esperado antes de arquivar, e sair diferente de 0
  quando não começa.
- **Card de mensagem rica é validado no servidor** *(herdada)*. JSON bem formado
  com schema errado devolve 400, não 200. Validar localmente pega metade dos
  erros; conferir o status da resposta é obrigatório.
- **Busca de helpdesk pagina, e o tamanho da página não é o total** *(herdada)*.
  `length` da amostra reportado como total subnotifica silenciosamente. Usar o
  campo de contagem total e marcar `truncado` quando a amostra for menor.
- **Consulta a log varre a janela inteira; métrica não** *(herdada)*. Filtro de
  entidade **seleciona, não impede a varredura**. Preferir métrica sempre que a
  pergunta puder ser respondida por ela, e manter poucas consultas de log por
  execução.
- **Deep link de app de observabilidade pode usar fragmento, não query string**
  *(herdada)*. `?query=...` navega e **não aplica filtro nenhum** — falha
  silenciosa, o pior tipo. Conferir que o link gerado chega com o filtro
  aplicado, não só que ele abre.

## 11. Critérios de aceite

Verificáveis, não aspiracionais. O estado atual de cada um vive em
[`TASKS.md`](TASKS.md).

- [ ] A suíte roda no CI a cada PR, **sem nenhum secret**
- [ ] `tests/casos/00-sanitizacao.sh` falha o CI diante de qualquer
      identificador da lista proibida
- [ ] Uma fonte derrubada de propósito aparece como `(fonte indisponível)` e
      **não** como ausência de problema
- [ ] Uma fonte sem credencial aparece como lacuna (🚧) e **não** como falha
- [ ] Uma execução que falha por erro de API sai com status ≠ 0 e **não** arquiva
      o erro como laudo
- [ ] Uma escrita que falha sai com status ≠ 0 e nunca é relatada como feita —
      inclusive a recusa por regra, provada contra dublê que registra requisições
- [ ] Uma operação proibida é recusada **pelo harness** — testada, não presumida
- [ ] Um ciclo completo — bug no board, worktree, correção, PR, CI verde,
      transição — executado ponta a ponta contra o alvo
- [ ] O laudo chega ao Slack sem ninguém olhar um terminal
- [ ] Uma pessoa que nunca viu o repositório sobe a ronda lendo só o
      `PRIMEIRO-DIA.md`
- [ ] As métricas do funil reproduzem, sobre a mesma amostra, o número calculado
      à mão no exercício de validação
