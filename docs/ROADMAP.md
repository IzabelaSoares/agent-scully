# Roadmap — Agent Scully

Horizontes **depois** do plano. O que está em construção e em que ordem está no
[`PLAN.md`](PLAN.md); aqui ficam as direções que ainda não são plano, e os riscos
abertos com o que segura cada um.

A distinção é deliberada: horizonte sem data não vira task, e task sem
dependência resolvida não vira commit.

Revisado em 08/09/2026.

---

## H1 — O segundo board

A política de prazo declarativa (Etapa 2) isola a parte que de fato varia entre
boards. **Isso não é o mesmo que ter um adaptador**, e a diferença importa: uma
abstração construída sobre um caso só é uma abstração que descreve aquele caso
com mais arquivos.

**O que destrava:** um segundo board de verdade, com semântica de prazo
diferente. Aí se vê o que é variação e o que era acidente.

## H2 — Conversar com o agente

`@scully` num comentário de PR ou de issue, respondido pelo mesmo agente que faz
a ronda, com o mesmo conjunto de permissões — nada de um caminho paralelo com
outra allowlist.

**Por que não está no plano:** o valor depende de haver alguém além da autora
usando o repositório. Antes disso é feature bonita sem usuário, e a Etapa 12
entrega mais.

## H3 — Painel público de processo

As métricas da Etapa 11 num painel aberto, junto do SLO do agente. É o horizonte
que transforma o repositório de "código que faz" em "resultado que se vê".

**O que segura:** exige que a Etapa 11 tenha rodado tempo suficiente para o
painel mostrar tendência em vez de ruído. Publicar tendência de duas semanas é
publicar ruído com eixo.

## H4 — Quality gate a partir do padrão sistêmico

Fechar o loop: o agrupamento da Etapa 12 aponta o módulo que mais gera bug, e
isso vira sugestão de onde investir teste — com o dado que sustenta a sugestão.

**O que segura:** precisa da Etapa 11 e de uma amostra de bug grande o bastante
para o agrupamento não ser coincidência. É o horizonte mais distante e o de
maior valor.

---

## Riscos e pontos em aberto

Nenhum destes é esquecimento. Cada um está aberto por uma dependência
identificada, e o que segura cada um está escrito para que a análise não se
refaça.

### 1. O alvo é sintético, e isso limita o funil

⚠️ **Este é o risco mais honesto do projeto.** As métricas de processo da Etapa
11 medem um funil que a própria autora alimenta. Elas provam que o **cálculo**
está correto — p50 e p90 sobre histórico real de mudança de status, conferidos à
mão —, e **não** provam que o processo medido é representativo de um time de
verdade.

**O que se faz com isso:** a validação do cálculo é o critério de aceite (SPEC
§11), não a plausibilidade do número. E o `ALVO.md` diz isso na primeira tela,
para que ninguém precise descobrir.

**O que destravaria:** aplicar as mesmas métricas a um board público de projeto
open source, onde o histórico não é fabricado. Candidato natural de H1.

### 2. Limite dos tiers gratuitos

APM e Langfuse gratuitos têm cota de ingestão e retenção curta. A retenção é o
que morde: métrica de funil quer histórico, e histórico é exatamente o que o
tier free descarta primeiro.

**Mitigação prevista:** o que precisa de histórico longo é extraído do board —
que guarda o histórico de status sem custo — e não do APM. O APM responde por
janela curta (saúde da ronda) e nunca é fonte de série longa.

### 3. Custo de token

A ronda chama modelo duas vezes por dia útil. É barato, e "é barato" não é
argumento que sobrevive a um laço com defeito.

**Mitigação prevista:** custo por execução medido e publicado desde a Etapa 4
(SPEC §8.3), com ausência de dado como `—` e nunca `0`. Medir antes de precisar
é o que permite responder à pergunta em vez de estimar.

### 4. Segredo em repositório público

Os secrets vivem no repositório do GitHub e nunca no código. O risco real não é
o secret vazar do cofre — é ele vazar **pelo log**: um `set -x` esquecido, um
`echo` de depuração, um erro que ecoa o header.

**Mitigação prevista:** regra de nunca imprimir credencial (SPEC §9) sustentada
por teste com segredo sentinela (task B3), não por atenção.

---

## Fora do roadmap, e por quê

**Substituir a pessoa de plantão.** SPEC §1. Muda o padrão de qualidade exigido,
não só o texto do laudo.

**Merge automático por CI verde.** SPEC §6. CI verde é pré-condição, não
autorização, e a primeira exceção é o fim da garantia.

**Alerta em tempo real.** SPEC §3. Ronda não é monitoramento.

**Triagem automática de issue mal tipada.** Tarefa tipada errada e parada há
meses é trabalho humano no board, não feature de agente. O radar segue
reportando — foi esconder que as deixou envelhecer.
