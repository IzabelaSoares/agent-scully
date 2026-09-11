# First day — Agent Scully

Do clone ao ponto mais distante que este repositório alcança **hoje**, em sete
passos. Cada passo termina numa **prova**: um comando cuja saída você confere, e
não uma afirmação para acreditar. É a mesma exigência que o agente tem de
cumprir no laudo ([`docs/SPEC.md`](docs/SPEC.md) §1), aplicada a quem chega.

> ⚠️ **Onde a trilha para.** Ela vai do clone até a **verificação de
> credenciais**. **Nenhum coletor está implementado** — não há ronda nem laudo
> ainda, e este arquivo não vai fingir que há. O que falta, e em que etapa
> chega, está em [Onde a trilha para hoje](#onde-a-trilha-para-hoje).

## Antes de começar

| Ferramenta | Para quê | Faltando, o que acontece |
|---|---|---|
| `git`, `bash`, `python3` | a suíte de testes | nada roda |
| `shellcheck` | verificação estática de todo shell | **a suíte falha** — não pula |
| `jq` | leitura de JSON, dos coletores em diante | nada hoje; instale junto |
| `curl` | a verificação de credenciais | ela sai ≠ 0 dizendo que nada foi verificado |

As duas linhas de "falha" acima não são aspereza gratuita. **Verificação que se
pula em silêncio é verificação que não existe** — e foi assim que um defeito
real sobreviveu semanas num projeto anterior ([`docs/SPEC.md`](docs/SPEC.md)
§10).

**Credencial não é pré-requisito de nada até o Passo 5.** Os quatro primeiros
passos rodam numa máquina sem `.env`, sem segredo e sem rede.

## Passo 1 — Clonar, e não ter nada a mais

```bash
git clone <url-deste-repositorio> agent-scully
cd agent-scully
git status --short
```

**Prova:** a saída do `git status --short` é **vazia**. Clone que já nasce sujo
esconde, no primeiro diff, o que você mesmo mudou.

Vale reparar em duas coisas agora, porque elas explicam o layout inteiro:
`CLAUDE.md` e `AGENTS.md` na raiz são **symlinks** para `.ai/INSTRUCTIONS.md` —
a documentação de agente tem fonte única, e editar o symlink é editar o alvo; e
`.env` está no `.gitignore`, de modo que a credencial que você vai preencher no
Passo 5 não tem como ser commitada por distração.

## Passo 2 — As ferramentas, e a verificação estática

```bash
sudo apt-get update && sudo apt-get install -y shellcheck jq
tests/run.sh 01-estatico
```

**Prova:** a última linha diz `OK`, e entre as asserções aparece
`✓ shellcheck instalado`. Sem o `shellcheck` no caminho, a mesma invocação
devolve `✗ shellcheck NÃO instalado` e o status de saída é ≠ 0 — não um aviso
amarelo que se aprende a ignorar.

## Passo 3 — A suíte inteira, sem credencial nenhuma

```bash
tests/run.sh
```

**Prova:** a última linha começa com `OK` e conta as asserções e os casos. Se
você tem um `.env` preenchido nesta máquina, rode de novo: **o resultado é o
mesmo**, porque a suíte se isola do arquivo por construção.

Nenhum caso toca a rede e nenhum lê credencial: tudo roda sobre
`tests/fixtures/`. É isso que permite ao CI rodar a cada pull request **sem
nenhum secret**, e é isso que permite a você rodar a suíte sem pedir acesso a
coisa alguma.

Para um caso só, passe parte do nome — `tests/run.sh 03-ambiente`.

## Passo 4 — Ver a rede de sanitização falhar de propósito

Os três passos anteriores mostraram a suíte passando. Passar é fraco: um teste
que nunca falhou não provou nada. Este passo arma a falha de propósito.

A regra que esta rede protege: **nenhum identificador de empresa, cliente ou
sistema interno de terceiro entra neste repositório**
([`docs/decisoes/0002-sanitizacao-verificada-por-teste.md`](docs/decisoes/0002-sanitizacao-verificada-por-teste.md)).
Uma das classes proibidas é a chave de issue de um board que não é o do alvo —
três a seis letras maiúsculas, hífen, dígitos.

```bash
printf '%s-%s\n' "ACME" "42" > experimento-da-rede.txt
git add experimento-da-rede.txt
tests/run.sh 00-sanitizacao
git rm -f experimento-da-rede.txt
```

**Prova:** a terceira linha **falha**, e a falha aponta `experimento-da-rede.txt`
e o número da linha — **sem imprimir o termo encontrado**, porque log de CI de
repositório público é público e um teste que imprime o achado publica
exatamente o que a lista existe para não publicar. O `git rm -f` desfaz o
experimento; rode `tests/run.sh 00-sanitizacao` de novo e ele volta a passar.

> O termo vai pelo `printf`, montado em tempo de execução, em vez de escrito
> literalmente aqui. Não é frescura: escrever a chave inteira nesta linha faria
> **este arquivo** falhar o caso — que é, de novo, a prova de que a rede
> funciona.

## Passo 5 — O `.env`, e a lacuna que ainda não é falha

```bash
cp .env.example .env
SCULLY_SEM_ENV=1 ops/verificar-credenciais.sh; echo "status: $?"
```

**Prova:** toda fonte aparece com 🚧 e o motivo, e o status impresso é `2`. Sem
`.env` nenhum, a verificação sai **2**. Aparecendo um ✅ aqui, você tem
credencial **exportada no ambiente** desta máquina — ela ganha do arquivo, e é
exatamente o que o Passo 6 mostra de propósito.

Os três estados, e o porquê de serem três:

| Marcador | Significa | Status de saída |
|---|---|---|
| ✅ | a chamada mínima respondeu 2xx com esta credencial | 0, quando é só isso |
| ❌ | a credencial está preenchida e a chamada não passou | 1 |
| 🚧 | não configurada, ou fonte que ainda não foi integrada | 2, quando não há ❌ |

**"Não configurada" não é "recusada".** Confundir as duas manda quem está de
plantão rotacionar um token que estava bom, às três da manhã — é o diagnóstico
mais caro que existe, e é por isso que a distinção é regra
([`docs/SPEC.md`](docs/SPEC.md) §11), não estilo de saída.

`SCULLY_SEM_ENV=1` ignora o arquivo por completo. Ele existe para a suíte não
depender da sua credencial nem vazá-la, e aqui serve para você ver o estado
"máquina recém-clonada" mesmo já tendo um `.env` ao lado.

## Passo 6 — O ambiente ganha do arquivo

Este é o passo que justifica a Etapa 1 inteira. Injete uma credencial inválida
por variável, com o `.env` no lugar:

```bash
BOARD_BASE_URL=https://exemplo.invalido \
BOARD_EMAIL=plantao@exemplo.invalido \
BOARD_API_TOKEN=invalido \
  ops/verificar-credenciais.sh; echo "status: $?"
```

**Prova:** a linha do board vira `❌ board` com o motivo, e o status é `1` — a
variável injetada **ganhou** do arquivo. Num script ingênuo, que faz
`set -a; source .env`, o arquivo ganharia e esta chamada passaria em silêncio
com a credencial boa.

O motivo exato depende da sua rede — `não resolveu o host` numa saída direta,
`curl saiu 56` atrás de um proxy que aceita a conexão e depois a corta. O que
não depende é o marcador: preenchida e não passou é ❌, nunca 🚧.

Duas consequências, e as duas doem:

- o **caminho de falha fica intestável** — todo teste de "a fonte caiu" escrito
  depois roda com a credencial boa e passa por engano;
- segredo injetado por variável (CI, `export` manual) é **descartado sem
  aviso**.

Está registrado como armadilha em [`docs/SPEC.md`](docs/SPEC.md) §10, e é a
razão de existir de `.ai/tools/lib/env.sh`. Este é o único passo deste arquivo
que tenta sair para a rede, e ele tenta de propósito para um domínio que não
resolve: `.invalido` é reservado para exatamente isto (RFC 2606).

## Passo 7 — As credenciais de verdade

Abra o [`.env.example`](.env.example) e preencha o seu `.env`. Cada seção diz,
para cada variável, **o que é, em que conta vive, quem emite, qual o escopo
mínimo e qual a validade** — é a informação que falta às três da manhã, quando
uma credencial expira. Valor com `&`, `?` ou espaço vai entre **aspas
simples**; URL de webhook tem os três.

```bash
ops/verificar-credenciais.sh; echo "status: $?"
```

**Prova:** cada credencial preenchida aparece com ✅ ou com ❌ e o motivo, e
**nenhum caractere de nenhum segredo aparece na saída** — nem em caso de erro,
nem quando a ferramenta de rede devolve o segredo na própria mensagem. Quem
garante isso é `tests/casos/05-credenciais.sh`, que grava um sentinela em cada
variável e falha se ele vazar.

Fica 🚧 o que ainda não tem como ser verificado aqui, **com o motivo e a etapa
em que chega**: o webhook do Slack só se confere postando, e postar é do wrapper
da Etapa 3; o APM e o helpdesk ainda não têm fornecedor escolhido (Etapas 6 e
8). Lacuna anunciada não é falha, e nenhuma das duas vira zero.

## Onde a trilha para hoje

Aqui. **Nenhum coletor está implementado** — `.ai/tools/coleta/` está vazio de
propósito, e diretório vazio neste repositório é etapa não começada, não lacuna
esquecida.

O que existe é o que os sete passos acima exercitaram: a especificação, a suíte,
o CI, a biblioteca de ambiente e a verificação de credenciais. O que falta para
uma ronda de verdade, na ordem em que chega
([`docs/PLAN.md`](docs/PLAN.md)):

| Etapa | O que ela destrava | Este arquivo ganha |
|---|---|---|
| 2 | radar de prazo no board, com a política de prazo declarativa | o primeiro comando que devolve dado de verdade |
| 3 | o laudo: template, golden file, contrato, postagem no Slack | o primeiro laudo, e a conferência dele |
| 4 | a ronda mora no GitHub Actions: cron e disparo manual | como agendar, e como disparar à mão |

Enquanto isso não existe, o passo seguinte a este arquivo não é rodar nada — é
ler [`docs/SPEC.md`](docs/SPEC.md) (o que o agente é e o que ele garante) e
[`docs/PLAN.md`](docs/PLAN.md) (por que as etapas estão nesta ordem — elas têm
dependência real, não preferência).

## Quando algum passo falha

| Sintoma | Causa provável |
|---|---|
| `✗ shellcheck NÃO instalado` | falta a ferramenta — o Passo 2 a instala; a suíte falha de propósito em vez de pular |
| `✗ sem bit de execução` | o clone perdeu o modo do arquivo; `chmod +x` no script apontado |
| `curl não está instalado — nada foi verificado` | mesma regra do `shellcheck`: nada foi verificado, e o script diz isso em vez de reportar 🚧 |
| `política ausente` | `.ai/politicas/verificacao.yaml` sumiu; sem ele não há tempo-limite, e chutar um número devolveria à mão o literal em script |
| `❌ .env tem linha malformada` | o número da linha está na saída — o conteúdo não, de propósito |
| `❌` em tudo, com "não resolveu o host" | rede ou proxy, não credencial |
| `🚧` em fonte que você preencheu | ela ainda não foi integrada; o motivo na própria linha diz em que etapa chega |

## Depois do primeiro dia

[`CONTRIBUTING.md`](CONTRIBUTING.md) tem a convenção de branch, de commit e de
pull request — inclusive a única que não tem exceção: **merge é humano**, e
**CI verde é pré-condição, não autorização**.

Este arquivo cresce a cada etapa, e não por boa vontade:
`tests/casos/06-primeiro-dia.sh` confere que todo caminho citado aqui existe,
que o código de saída prometido no Passo 5 é o que o script devolve, e que a
frase "nenhum coletor está implementado" cai no dia em que o primeiro coletor
entrar.
