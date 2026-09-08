# Documentation conventions (`.ai/`)

> Meta-documento: explica como `.ai/` é organizado e como evoluí-lo. O conteúdo
> de produto está no [`INSTRUCTIONS.md`](INSTRUCTIONS.md) e em `docs/`.

## Princípio: fonte única + symlinks

Toda a documentação e o ferramental para agentes vivem em **`.ai/`**. Os caminhos
que cada ferramenta espera são **symlinks** apontando para cá:

| Caminho | Aponta para | Ferramenta |
|---|---|---|
| `CLAUDE.md` (raiz) | `.ai/INSTRUCTIONS.md` | Claude Code (carrega automaticamente) |
| `AGENTS.md` (raiz) | `.ai/INSTRUCTIONS.md` | padrão genérico de outros agentes |
| `.claude/commands` | `.ai/commands` | Claude Code (slash commands) |
| `.claude/skills` | `.ai/skills` | Claude Code (skills sob demanda) |

**Edite sempre dentro de `.ai/`. Nunca edite os symlinks** — são só ponteiros.

`.claude/settings.json` **não** é symlink e não vive em `.ai/`: é configuração de
harness (permissões), não documentação. Só o Claude Code o lê, e é ele que
*aplica* a restrição — ver a distinção de camadas na
[`SPEC`](../docs/SPEC.md) §6.

## Layout

```
.ai/
  INSTRUCTIONS.md   ← índice always-loaded: o que é, estado, regras, sumário
  CONVENTIONS.md    ← este arquivo
  docs/             ← referência descritiva (descreve, não manda)
  rules/            ← padrões acionáveis (manda), lidos sob demanda
  politicas/        ← limiar e regra como dado declarativo, versionado e testado
  tools/            ← código determinístico, sem LLM
    coleta/           # devolvem JSON normalizado; só GET
    acoes/            # as escritas, com a restrição embutida no wrapper
    lib/              # comum (ambiente, http, limites)
  templates/        ← formatos de saída; o agente preenche, não inventa
  skills/           ← procedimento sob demanda: recebe o JSON e julga
  commands/         ← ponto de entrada: janela + composição
```

## Onde ponho um arquivo novo?

Na ordem, a primeira pergunta cuja resposta for "sim":

1. **É um número que se ajusta sem decisão explícita?** → `politicas/`. Limiar
   não vira literal em script nem prosa em documento (SPEC §9.1).
2. **É código que sempre faz a mesma coisa e não precisa de modelo?** → `tools/`.
   Se pode ser script, é script. Coletor vai em `tools/coleta/` e devolve JSON
   pequeno e normalizado — o ganho de contexto não vem de ser script, vem de
   **moldar a saída**. Escrita vai em `tools/acoes/`, com a restrição embutida.
3. **É um formato de saída?** → `templates/`.
4. **É uma restrição que não se ajusta sem decisão explícita?** → `rules/`.
   Cuidado: limiar não é regra, é calibragem — pergunta 1.
5. **É um procedimento passo a passo de um domínio?** → `skills/<nome>/SKILL.md`.
6. **É material de referência que alguém consulta?** → `docs/`.

Não cabendo em nenhuma, provavelmente é conteúdo do `INSTRUCTIONS.md` — mas
pense duas vezes: ele é índice, e índice que cresce deixa de ser lido.

**Mudou a forma do sistema e não é óbvio pelo código?** → uma entrada em
[`docs/decisoes/`](../docs/decisoes/README.md), com as cinco seções, **incluindo as
alternativas descartadas e o motivo do descarte**.

## Regras de conteúdo

- **Tudo em português brasileiro.** Nome de arquivo e título H1 em inglês.
- **Sem duplicação:** cada fato mora em um arquivo; os demais linkam.
- **Links internos relativos ao próprio arquivo** — é o que o GitHub renderiza.
  **Uma exceção, e é deliberada:** `INSTRUCTIONS.md` usa caminho relativo à
  **raiz**, porque a ferramenta o lê através do symlink `CLAUDE.md`, que está na
  raiz. O preço é que os links dele não resolvem ao navegar `.ai/INSTRUCTIONS.md`
  no GitHub — e o preço inverso seria não resolverem para o agente, que é quem
  os segue. `tests/verificar-links.py` conhece a exceção e verifica as duas
  bases.
- **Toda armadilha descoberta vai para a SPEC §10 com data e evidência.** Cada
  uma custa horas de alguém; **sem a evidência, a próxima pessoa desfaz.**
- **Nenhuma afirmação de estado sem teste que a sustente.** "Roda em produção" e
  "implementado e testado" são estados diferentes, e confundi-los é como um
  README deixa de ser confiável.

## Formato do `SKILL.md`

Frontmatter YAML com **só** `name` e `description`:

```yaml
---
name: nome-em-kebab-case
description: >
  Descrição em terceira pessoa. Use when [situações de ativação].
  Palavras-chave que a pessoa usaria ao pedir a tarefa.
---
```

Nada de `version`, `models` ou `compatibility`: são não-padrão, nenhuma
ferramenta os lê e envelhecem rápido. Corpo de 80 a 200 linhas, na ordem
Propósito → Quando usar → Pré-condições → Mapa de arquivos → Passo a passo →
Armadilhas.

## Testes

Toda mudança em `tools/` roda contra `tests/run.sh`, que **não usa credencial
nenhuma** — tudo sobre `tests/fixtures/`. É isso que torna o CI viável a cada
PR, e é isso que torna a suíte rodável por quem clonar sem pedir acesso a nada.
