#!/usr/bin/env bash
#
# Verificação estática de todo shell e todo Python rastreado.
#
# ⚠️ Ferramenta ausente FALHA, não pula. Verificação que se pula em silêncio é
# verificação que não existe — foi assim que um defeito real sobreviveu semanas
# num projeto anterior (SPEC §10).

set -uo pipefail
cd "$RAIZ" || exit 1

if command -v shellcheck >/dev/null 2>&1; then
  printf '✓ shellcheck instalado\n'
  mapfile -t scripts < <(git ls-files '*.sh')
  if [ "${#scripts[@]}" -eq 0 ]; then
    printf '✗ nenhum script encontrado para verificar\n'
  elif shellcheck -S warning "${scripts[@]}"; then
    printf '✓ shellcheck sem achado em %s script(s)\n' "${#scripts[@]}"
  else
    printf '✗ shellcheck com achado\n'
  fi
else
  printf '✗ shellcheck NÃO instalado — a verificação estática de shell não rodou\n'
  printf '    instale: sudo apt-get install -y shellcheck\n'
fi

mapfile -t pys < <(git ls-files '*.py')
if [ "${#pys[@]}" -eq 0 ]; then
  printf '✓ nenhum Python rastreado (nada a verificar)\n'
elif python3 -m py_compile "${pys[@]}" 2>/dev/null; then
  printf '✓ sintaxe válida em %s arquivo(s) Python\n' "${#pys[@]}"
  find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
else
  printf '✗ erro de sintaxe em Python\n'
  python3 -m py_compile "${pys[@]}"
fi

# Todo script versionado tem shebang e bit de execução: script sem um dos dois
# falha só na hora em que alguém precisa dele.
faltando=0
while IFS= read -r s; do
  head -1 "$s" | grep -q '^#!' || { printf '✗ sem shebang: %s\n' "$s"; faltando=1; }
  [ -x "$s" ] || { printf '✗ sem bit de execução: %s\n' "$s"; faltando=1; }
done < <(git ls-files '*.sh')
[ "$faltando" -eq 0 ] && printf '✓ todo shell rastreado tem shebang e bit de execução\n'
