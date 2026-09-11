#!/usr/bin/env bash
#
# A política de prazo é dado, e é a única fonte (TASKS C1, decisões 0003).
#
# A primeira metade roda o verificador sobre os arquivos de verdade. A segunda
# é a que importa mais: cinco dublês quebrados de propósito, um por modo de
# falha, porque **teste de negação que nunca falhou não prova nada** — é a
# mesma razão do canário da sanitização.
#
# Os cinco, e o estrago que cada um evita:
#
#   lista-vazia   origem sem campo de prazo — a fila inteira invisível, e em
#                 silêncio, que é o pior jeito de ficar invisível
#   sem-razao     valor sem a razão ao lado — ninguém sabe ajustar, e a regra
#                 fica errada por inércia
#   malformado    `.yaml` fora do subconjunto — tem que falhar como falha, com
#                 o número da linha, nunca virar lista vazia
#   divergente    documentação desatualizada ao lado da política boa — o mesmo
#                 valor em dois lugares diverge em semanas
#   com-literal   coletor escolhendo campo por `if` — o que a decisão 0003
#                 descartou, e o que esta rede impede de voltar
#
# A saída dos dublês é capturada, nunca ecoada: o ✗ deles é o esperado, e
# ecoá-lo faria o run.sh contá-lo como falha da suíte.
#
# Roda sem credencial e sem rede: tudo é arquivo em tests/fixtures/.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

POLITICA="$RAIZ/.ai/politicas/prazo.yaml"
DOC="$RAIZ/.ai/docs/prazo.md"
FIX="$FIXTURES/prazo"

afirmar_arquivo "$POLITICA" 'existe: .ai/politicas/prazo.yaml'
afirmar_arquivo "$DOC" 'existe: .ai/docs/prazo.md'

# ─── 1. Os arquivos de verdade ──────────────────────────────────────────────
# O ✓ de cada verificação vem do próprio verificador.

python3 tests/prazo/verificar.py

# ─── 2. Os dublês ───────────────────────────────────────────────────────────

# canario <nome-do-dublê> <mensagem-esperada> <descrição> [argumento...]
canario() {
  local nome="$1" esperado="$2" descricao="$3"
  shift 3
  local saida status
  saida="$(python3 tests/prazo/verificar.py "$@" 2>&1)"
  status=$?
  afirmar_igual '1' "$status" "$nome: o verificador sai 1"
  afirmar_contem "$esperado" "$saida" "$descricao"
}

canario 'lista-vazia' \
  '✗ toda origem tem lista de campos não vazia' \
  'origem sem campo de prazo é recusada, em vez de virar fila vazia' \
  --politica "$FIX/lista-vazia/prazo.yaml" --doc "$FIX/lista-vazia/prazo.md"

canario 'sem-razao' \
  'sem razão' \
  'valor sem a razão ao lado é recusado, com o número da linha' \
  --politica "$FIX/sem-razao/prazo.yaml" --doc "$FIX/sem-razao/prazo.md"

canario 'malformado' \
  'fora do subconjunto' \
  'o que sai do subconjunto é recusado, e a recusa diz a linha' \
  --politica "$FIX/malformado/prazo.yaml" --doc "$FIX/malformado/nao-existe.md"

canario 'divergente' \
  '✗ a tabela de' \
  'documentação divergente da política falha o caso' \
  --politica "$FIX/divergente/prazo.yaml" --doc "$FIX/divergente/prazo.md"

canario 'com-literal' \
  'cita um campo' \
  'nome de campo literal em script é pego, com arquivo e linha' \
  --script "$FIX/com-literal/coletor-fake.sh"

# O dublê com literal só prova alguma coisa se o nome estiver mesmo lá: um
# verificador que não achasse nada passaria por vacuidade, e não por acerto.
afirmar_contem 'if [ "$origem"' "$(cat "$FIX/com-literal/coletor-fake.sh")" \
  'o dublê do literal é mesmo um coletor que escolhe por `if`'

# ─── 3. A recusa não imprime o valor do campo ───────────────────────────────
# Nome de campo não é segredo, mas o hábito é: id e nome de campo de um board
# real identificam a instância de quem o tem (decisões 0002). O achado sai como
# arquivo e linha, e quem quiser ver abre o arquivo.

saida="$(python3 tests/prazo/verificar.py \
  --script "$FIX/com-literal/coletor-fake.sh" 2>&1)"
achado="$(printf '%s\n' "$saida" | grep 'cita um campo')"
afirmar_contem 'coletor-fake.sh:' "$achado" 'o achado diz o arquivo e a linha'

# ─── 4. A política não é consumida por ninguém ainda ────────────────────────
# Catraca: o dia em que um coletor entrar, esta asserção cai e obriga a
# documentação a parar de dizer que não há radar (TASKS C2).

mapfile -t coletores < <(git ls-files '.ai/tools/coleta/*.sh')
if [ "${#coletores[@]}" -eq 0 ]; then
  afirmar_contem 'Não garante:** que exista coletor' "$(cat "$DOC")" \
    'sem coletor, a documentação declara que a política ainda não é lida por ninguém'
else
  afirmar_nao_contem 'Não garante:** que exista coletor' "$(cat "$DOC")" \
    "há ${#coletores[@]} coletor(es): a documentação precisa deixar de dizer que não há"
fi
