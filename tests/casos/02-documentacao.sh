#!/usr/bin/env bash
#
# A documentação é navegável: todo link interno resolve, a fonte única está
# symlinkada, e os documentos que a SPEC referencia existem.
#
# Link quebrado em documentação de agente não é cosmético: o agente segue o
# link, não encontra, e segue sem o contexto que a instrução mandava carregar.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

for doc in README.md CONTRIBUTING.md LICENSE \
  docs/SPEC.md docs/PLAN.md docs/TASKS.md docs/ROADMAP.md docs/ALVO.md \
  docs/decisoes/README.md .ai/INSTRUCTIONS.md .ai/CONVENTIONS.md; do
  afirmar_arquivo "$doc" "existe: $doc"
done

for link in CLAUDE.md AGENTS.md .claude/commands .claude/skills; do
  if [ -L "$link" ]; then
    printf '✓ %s é symlink\n' "$link"
  else
    printf '✗ %s deveria ser symlink (a fonte única é .ai/)\n' "$link"
  fi
  if [ -e "$link" ]; then
    printf '✓ %s aponta para algo que existe\n' "$link"
  else
    printf '✗ %s é symlink pendurado\n' "$link"
  fi
done

python3 tests/verificar-links.py
