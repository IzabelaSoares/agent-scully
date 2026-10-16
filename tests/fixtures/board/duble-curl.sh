#!/usr/bin/env bash
#
# Dublê de `curl` que responde uma SEQUÊNCIA combinada, sem tocar a rede.
#
# Existe para exercitar o que o board ainda não pode exercitar: a retentativa e
# os dois estados de falha (TASKS C4). O board do alvo nasce na Etapa 5, e até
# lá este arquivo é o único jeito de provar que o coletor insiste duas vezes e
# desiste declarando — em vez de devolver fila vazia.
#
# Combinação, por variável de ambiente:
#
#   DUBLE_SEQUENCIA   respostas separadas por espaço, uma por chamada. Cada uma
#                     é um código HTTP ou a palavra `timeout`. Esgotada a lista,
#                     a última se repete — `500` sozinho é "500 sempre".
#   DUBLE_CONTADOR    arquivo onde se acumula uma linha por chamada. É o
#                     contador (quantas tentativas o coletor fez) e é o que diz
#                     em que ponto da sequência estamos.
#   DUBLE_CORPO       arquivo com o corpo a devolver numa resposta 2xx.
#   DUBLE_ARGV        arquivo onde se registram os argumentos recebidos.
#   DUBLE_STDIN       arquivo onde se registra o que veio pelo STDIN.
#
# ⚠️ **Ele emula o `--write-out` do `curl`:** o corpo, e depois uma linha com o
# código HTTP. É assim que o coletor lê o código, e é o que o `curl` de verdade
# faz com `--write-out '\n%{http_code}'`. Emular diferente faria o caso passar
# sobre um comportamento que não é o do `curl`.
#
# ⚠️ O corpo de erro é JSON **bem formado** de propósito. Um coletor que
# ignorasse o código HTTP o normalizaria sem reclamar: sem `issues`, a conta dá
# zero, e o estourado vira fila vazia — a falha silenciosa que a SPEC §1 proíbe
# e que esta sequência existe para pegar.

set -uo pipefail

[ -n "${DUBLE_ARGV:-}" ] && printf '%s\n' "$@" >>"$DUBLE_ARGV"
cat >>"${DUBLE_STDIN:-/dev/null}"

chamadas=0
if [ -n "${DUBLE_CONTADOR:-}" ]; then
  printf 'chamada\n' >>"$DUBLE_CONTADOR"
  chamadas="$(wc -l <"$DUBLE_CONTADOR")"
fi

read -r -a sequencia <<<"${DUBLE_SEQUENCIA:-200}"
[ "${#sequencia[@]}" -gt 0 ] || sequencia=(200)

indice=$((chamadas - 1))
[ "$indice" -lt 0 ] && indice=0
[ "$indice" -ge "${#sequencia[@]}" ] && indice=$((${#sequencia[@]} - 1))
resposta="${sequencia[$indice]}"

if [ "$resposta" = 'timeout' ]; then
  # O `curl` de verdade também imprime o `--write-out` quando estoura o
  # tempo-limite, com o código em 000 — e sai 28.
  printf '\n000'
  exit 28
fi

case "$resposta" in
  2??)
    if [ -n "${DUBLE_CORPO:-}" ] && [ -f "${DUBLE_CORPO:-}" ]; then
      printf '%s' "$(<"$DUBLE_CORPO")"
    else
      printf '{}'
    fi
    ;;
  *) printf '{"errorMessages":["a fonte nao respondeu"],"errors":{}}' ;;
esac
printf '\n%s' "$resposta"
