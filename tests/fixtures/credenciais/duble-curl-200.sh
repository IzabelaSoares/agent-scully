#!/usr/bin/env bash
#
# Dublê de `curl` que responde 200 sem tocar a rede.
#
# Registra o que recebeu — argumentos em `$DUBLE_ARGV`, configuração do STDIN em
# `$DUBLE_STDIN` — porque as duas asserções que importam são sobre isso: o
# segredo tem que chegar pelo STDIN (senão a verificação não verifica nada) e
# **não** pode chegar por argumento (que `ps` lê).

set -uo pipefail

[ -n "${DUBLE_ARGV:-}" ] && printf '%s\n' "$@" >>"$DUBLE_ARGV"
cat >>"${DUBLE_STDIN:-/dev/null}"

printf '200'
