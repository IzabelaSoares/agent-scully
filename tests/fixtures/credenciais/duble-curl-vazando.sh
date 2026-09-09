#!/usr/bin/env bash
#
# Dublê de `curl` que VAZA de propósito: devolve em stdout e em stderr tudo o
# que recebeu — argumentos e configuração — e sai com o status de `$DUBLE_STATUS`.
#
# Modela os dois jeitos reais de um segredo escapar por uma ferramenta de rede:
# o corpo da resposta ecoando o que foi enviado, e a mensagem de erro citando a
# URL inteira. Um script que repassa a saída do curl passa nos testes de
# caminho feliz e vaza no primeiro erro — que é justamente quando alguém está
# olhando o terminal.

set -uo pipefail

[ -n "${DUBLE_ARGV:-}" ] && printf '%s\n' "$@" >>"$DUBLE_ARGV"
entrada="$(cat)"
[ -n "${DUBLE_STDIN:-}" ] && printf '%s\n' "$entrada" >>"$DUBLE_STDIN"

printf 'ARGS: %s\nSTDIN: %s\n' "$*" "$entrada"
printf 'ARGS: %s\nSTDIN: %s\n' "$*" "$entrada" >&2

exit "${DUBLE_STATUS:-7}"
