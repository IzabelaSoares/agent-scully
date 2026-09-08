#!/usr/bin/env bash
#
# Roda toda a suíte. Status != 0 se qualquer asserção falhar.
#
# Nenhum caso usa credencial nem toca a rede: tudo roda sobre tests/fixtures/.
# É isso que permite rodar no CI sem nenhum secret, e que permite a qualquer
# pessoa que clone rodar a suíte sem pedir acesso a nada.
#
# Uso: tests/run.sh [nome-parcial-do-caso]

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export RAIZ
export FIXTURES="$RAIZ/tests/fixtures"
FILTRO="${1:-}"

# Isola do .env da máquina: teste não deve depender de credencial nem vazar uma.
export SCULLY_SEM_ENV=1

total_ok=0 total_falha=0 casos=0

for caso in "$RAIZ"/tests/casos/*.sh; do
  nome="$(basename "$caso")"
  if [ -n "$FILTRO" ]; then
    case "$nome" in *"$FILTRO"*) ;; *) continue ;; esac
  fi
  casos=$((casos + 1))
  printf '\n\033[1m── %s\033[0m\n' "$nome"
  saida="$(bash "$caso" 2>&1)"
  echo "$saida"
  o=$(grep -c '✓' <<<"$saida" || true)
  f=$(grep -c '✗' <<<"$saida" || true)
  total_ok=$((total_ok + o))
  total_falha=$((total_falha + f))
done

printf '\n────────────────────────────────────────\n'
if [ "$casos" -eq 0 ]; then
  printf '\033[31mFALHOU\033[0m — nenhum caso casou com o filtro %s\n' "${FILTRO:-<vazio>}"
  exit 1
fi
if [ "$total_falha" -gt 0 ]; then
  printf '\033[31mFALHOU\033[0m — %s ok, %s falha(s), em %s caso(s)\n' \
    "$total_ok" "$total_falha" "$casos"
  exit 1
fi
printf '\033[32mOK\033[0m — %s asserções em %s caso(s)\n' "$total_ok" "$casos"
