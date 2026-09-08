# O alvo — `meridian-assist`

> **Leia isto primeiro: a empresa Meridian não existe.** O serviço vigiado por
> este agente é um alvo de demonstração, construído para o projeto e declarado
> como tal em todo lugar onde poderia ser confundido com um sistema real.

Referenciado pela [`SPEC.md`](SPEC.md) §5.1 e construído na Etapa 5 do
[`PLAN.md`](PLAN.md).

## Por que existe um alvo, e por que ele é fictício

Um agente de plantão sem serviço para vigiar é uma vitrine: o código existe,
nada acontece, e quem avalia não consegue distinguir o que funciona do que
compila.

Um agente de plantão apontado para o serviço de um empregador é um agente que
não pode ser publicado.

**O alvo fictício resolve os dois**, e ganha uma terceira propriedade que
nenhuma das alternativas tem: **reprodutibilidade**. A carga é sintética e o
gerador é versionado, então o comportamento do agente pode ser reproduzido por
quem clonar o repositório. Num alvo real, cada execução observaria um mundo
diferente e nenhum resultado seria conferível por terceiro.

## O que é fictício e o que é real

| | |
|---|---|
| **Fictício** | a empresa, o nome do produto, os usuários, o conteúdo das conversas, o volume de tráfego |
| **Real** | o serviço, que roda e falha de verdade; a instrumentação; o board de bug e sua fila; o repositório e seu CI; os pull requests que o agente abre; o laudo que chega ao Slack |

O que **não** existe em lugar nenhum deste repositório: identificador de empresa
real, de cliente, de instância de terceiro ou de sistema interno de qualquer
organização. Isso é verificado por `tests/casos/00-sanitizacao.sh`, que falha o
CI — ver
[`decisoes/0002-sanitizacao-verificada-por-teste.md`](decisoes/0002-sanitizacao-verificada-por-teste.md).

## O serviço

`meridian-assist` é um assistente de LLM que responde dúvidas de colaboradores
sobre políticas internas, abre ticket quando não resolve e escala para fila
humana.

A forma foi escolhida por três razões, e não por gosto:

1. **É uma aplicação de LLM**, então tem uma classe de falha que serviço comum
   não tem: erro de tool e resposta errada entregue com status 200. É o que
   justifica a camada de observabilidade de LLM da SPEC §5.2 — e é a falha que
   nem o APM nem o helpdesk enxergam.
2. **Tem transbordo para fila humana**, o que produz a distinção "preso com o
   bot" vs. "escalado" que a seção de helpdesk do laudo usa.
3. **Tem dado pessoal por natureza** — nome de colaborador no assunto do ticket,
   conversa no trace. É o que torna a regra de privacidade da SPEC §9 uma
   restrição exercida, e não uma frase.

O terceiro ponto é o mais importante: **uma regra de privacidade que nunca teve
oportunidade de ser violada não foi testada.** O alvo é desenhado para dar essa
oportunidade em cada execução.

## A carga sintética

Versionada junto do serviço, com perfis nomeados:

| Perfil | O que exercita |
|---|---|
| `normal` | tráfego de dia útil, taxa de erro baixa |
| `sem-trafego` | zero requisição — o caso ⚪ da SPEC §7, que cairia em 🟢 num gerador ingênuo |
| `erro-externo` | falha em dependência que **não** derruba a requisição — o caso do 🟢 com dezenas de erros de log |
| `erro-de-tool` | falha na camada de LLM invisível para o APM |
| `pico` | rajada, para o agrupamento de erro ter o que agrupar |

Os cinco perfis são os cinco casos que a SPEC exige que o laudo saiba
distinguir. **O gerador de carga é, na prática, a suíte de aceite do contrato de
saída** — a diferença é que ele exercita o caminho completo, com rede e
credencial, em vez de fixture.

## Onde ele vive

Repositório próprio, separado deste. Não é organização de arquivos: o fix agent
da Etapa 10 abre pull request **contra outro repositório**, e um alvo dentro
deste repositório tornaria esse caminho impossível de exercer de verdade.
