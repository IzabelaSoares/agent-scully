# Permissões — a amarração das três camadas

> Referência consultada sob demanda. O princípio está na
> [`SPEC`](../../docs/SPEC.md) §6 e o raciocínio em
> [`decisoes/0001`](../../docs/decisoes/0001-restricao-na-camada-mais-forte.md).
> **Leia antes de mexer em `.claude/settings.json` ou em `.ai/tools/acoes/`.**

Cada linha abaixo diz **onde** a restrição é imposta de fato. A coluna mais à
esquerda que estiver preenchida é a que vale; as demais existem para documentar
a intenção, não para garanti-la.

## Estado desta tabela

⚠️ **Etapa 0.** Nenhum coletor e nenhum wrapper existe ainda. A coluna
"capacidade" está preenchida com o que **será** construído, e está marcada como
tal. Uma linha sem `✅` não é uma garantia — é um plano.

| Capacidade | Camada que impõe | Estado |
|---|---|---|
| Ler board, helpdesk, APM, Langfuse | coletor só faz `GET` | 🚧 Etapas 2, 6, 7, 8 |
| Criar bug **com a label** | wrapper injeta a label | 🚧 Etapa 9 |
| Comentar **só em issue com a label** | wrapper consulta e recusa | 🚧 Etapa 9 |
| Transicionar **só com PR aberto** | wrapper verifica o PR primeiro | 🚧 Etapa 9 |
| Liberar (mover + tirar assignee) | endpoint dedicado de assignee | 🚧 Etapa 9 |
| **Não** editar campo de issue | nenhum wrapper sabe fazer | ✅ por ausência |
| **Não** usar MCP para as quatro escritas | `deny` em `settings.json` | ✅ |
| **Não** fazer merge, fechar PR, alterar review | `deny` em `settings.json` | ✅ |
| **Não** force-push, **não** push na base | `deny` em `settings.json` | ✅ |
| **Não** imprimir credencial | `deny` de `env`/`printenv`/`.env` | ✅ parcial — ver abaixo |
| **Não** vazar identificador de origem privada | teste que falha o CI | ✅ |

## Por que as ferramentas de MCP das operações permitidas estão negadas

**Operação permitida não é caminho permitido.** A restrição real — label sempre
injetada, só comentar em issue que a tenha, transição só com PR verificado —
vive no wrapper. Um caminho que não passa pelo wrapper é um caminho sem
restrição, mesmo que a operação final seja idêntica.

Negar a ferramenta de MCP não é redundância: é o que impede o modelo de escolher
o atalho quando o wrapper recusa.

## Por que allowlist, e não denylist

Uma lista de negação pressupõe uma pessoa como caso-padrão: chamada desconhecida
abre prompt e alguém decide. **Em job automático não existe esse alguém — o que
não estiver negado executa.**

Então a execução automática passa `--allowedTools` explícito, e o `deny` deste
arquivo é **segunda linha** e documentação do que é proibido de propósito. O dia
em que os dois divergirem, o `--allowedTools` é quem manda.

## O `deny` de credencial é parcial, e isso é conhecido

`env`, `printenv` e `cat .env` estão negados, e isso cobre o gesto óbvio. **Não
cobre** um `echo "$TOKEN"` dentro de um script, nem um `set -x` esquecido, nem
um erro que ecoa o header — porque a chamada que vaza é uma chamada permitida.

A camada que cobre isso é teste: a task B3 do [`TASKS`](../../docs/TASKS.md) grava um
segredo sentinela no ambiente e falha se ele aparecer em qualquer saída. É a
diferença entre negar o gesto e verificar o resultado, e as duas são
necessárias.

## Verificar que o harness recusa de fato

⚠️ **A estrutura do `deny` tem teste; a recusa efetiva, não.** Um caso da suíte
pode verificar que a chave está no arquivo — não que o harness a aplica. Isso
depende de rodar o harness, e continua sendo procedimento manual:

1. Numa sessão do agente neste repositório, pedir explicitamente uma das
   operações negadas.
2. Confirmar que a chamada é **recusada**, e não que o modelo apenas se recusou
   a tentar. As duas coisas parecem iguais na transcrição e são
   completamente diferentes: a segunda é obediência, e obediência não é garantia.
3. Registrar a data da verificação neste arquivo.

**Última verificação manual: nunca.** É um dos critérios de aceite em aberto da
[`SPEC`](../../docs/SPEC.md) §11.
