#!/usr/bin/env bash
#
# Asserções da suíte. Cada caso soma ✓ e ✗ na saída; tests/run.sh conta.

afirmar() {
  # afirmar <condicao-como-status> <mensagem>  — via `if ...; then afirmar 0 ...`
  if [ "$1" -eq 0 ]; then printf '✓ %s\n' "$2"; else printf '✗ %s\n' "$2"; fi
}

afirmar_igual() {
  local esperado="$1" obtido="$2" msg="$3"
  if [ "$esperado" = "$obtido" ]; then
    printf '✓ %s\n' "$msg"
  else
    printf '✗ %s\n' "$msg"
    printf '    esperado: %s\n    obtido:   %s\n' "$esperado" "$obtido"
  fi
}

afirmar_contem() {
  local agulha="$1" palheiro="$2" msg="$3"
  if printf '%s' "$palheiro" | grep -qF -- "$agulha"; then
    printf '✓ %s\n' "$msg"
  else
    printf '✗ %s\n' "$msg"
    printf '    não encontrou: %s\n' "$agulha"
  fi
}

afirmar_nao_contem() {
  local agulha="$1" palheiro="$2" msg="$3"
  if printf '%s' "$palheiro" | grep -qF -- "$agulha"; then
    printf '✗ %s\n' "$msg"
    printf '    encontrou o que não devia\n'
  else
    printf '✓ %s\n' "$msg"
  fi
}

afirmar_arquivo() {
  if [ -e "$1" ]; then printf '✓ %s\n' "$2"; else printf '✗ %s (ausente: %s)\n' "$2" "$1"; fi
}
