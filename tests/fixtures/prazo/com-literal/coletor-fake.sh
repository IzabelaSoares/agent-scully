#!/usr/bin/env bash
#
# Dublê: coletor que escolhe o campo de prazo por literal, em vez de ler a
# política. É o `if` no coletor que a decisão 0003 descartou — e é o canário
# que prova que o verificador sabe pegá-lo.
#
# Este arquivo não é chamado por ninguém: ele existe para ser lido.

set -uo pipefail

prazo_de() {
  local origem="$1"
  if [ "$origem" = 'cliente' ]; then
    printf '%s' 'Prazo do cliente'
  else
    printf '%s' 'Data limite'
  fi
}

prazo_de "${1:-interno}"
