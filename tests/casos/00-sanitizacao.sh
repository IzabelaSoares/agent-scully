#!/usr/bin/env bash
#
# Nenhum identificador de origem privada entrou no repositório.
#
# É a decisão 0002 aplicada: a fronteira entre "engenharia, que é do
# engenheiro" e "identificador, que é da organização" é verificada por teste,
# não por revisão — porque o repositório vai crescer por meses e o erro é
# irreversível.
#
# O verificador reporta arquivo e linha, nunca o termo. Ver
# tests/sanitizacao/README.md.

set -uo pipefail
cd "$RAIZ" || exit 1

python3 tests/sanitizacao/verificar.py

# A lista tem que ser capaz de falhar. Um teste de negação que passa numa
# árvore limpa não prova nada sobre o dia em que a árvore não estiver limpa.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
canario="$tmp/canario.md"
# ⚠️ O canário é decodificado, não escrito literal. Escrito literal, ele faria
# ESTE arquivo casar com o padrão que ele existe para testar — e a primeira
# versão deste caso falhou exatamente assim.
printf '%s' 'Y29udGF0bzogYWxndWVtQGV4ZW1wbG8uY29tLmJyCg==' | base64 -d >"$canario"
if python3 - "$canario" <<'PY'
import re, sys, pathlib
sys.path.insert(0, "tests/sanitizacao")
from verificar import carregar_padroes
padroes = carregar_padroes(pathlib.Path("tests/sanitizacao/padroes.txt"))
texto = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
sys.exit(0 if any(r.search(texto) for r, _ in padroes) else 1)
PY
then
  printf '✓ a lista de padrões pega um canário plantado\n'
else
  printf '✗ a lista de padrões NÃO pega um canário plantado\n'
fi
