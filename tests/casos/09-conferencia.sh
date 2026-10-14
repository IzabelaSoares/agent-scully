#!/usr/bin/env bash
#
# O radar reproduz o número conferido à mão (TASKS C3).
#
# A conferência está em `tests/fixtures/board/conferencia.md`: a conta de cada
# issue da amostra, escrita célula a célula a partir da política, **antes** de
# rodar o radar. Ela não é documentação sobre este caso — ela **é** o esperado
# deste caso.
#
# **Por que num arquivo, e não em asserção escrita aqui:** o critério da C3 pede
# que a conferência fique registrada, e não no histórico de conversa de quem a
# fez. Número conferido uma vez num terminal morre ali; o radar fica livre para
# mudar de resposta depois, e ninguém refaz a conta. Num arquivo versionado, o
# dia em que o radar mudar de resposta é um diff: ou a conferência muda junto, e
# a conta nova aparece do lado da antiga, ou o caso cai.
#
# A primeira metade roda o verificador sobre a conferência de verdade. A segunda
# é a que importa mais: quatro dublês quebrados de propósito, um por modo de
# falha, porque **teste de negação que nunca falhou não prova nada** — é a mesma
# razão dos cinco dublês do caso 07.
#
# Os quatro, e o estrago que cada um evita:
#
#   numero-errado         número errado ao lado de uma conta certa — esperado
#                         errado é verde que mente, e é o pior resultado da
#                         suíte inteira
#   data-fora-da-amostra  conta que fecha sozinha sobre data que a amostra não
#                         tem — conferir issue imaginária não prova nada
#   issue-sem-linha       issue da amostra sem linha na conferência — a amostra
#                         cresce e ninguém confere o que cresceu
#   classificacao-errada  conta certa e classificação que o radar contradiz — é
#                         o dublê que prova que a comparação sabe falhar
#
# A saída dos dublês é capturada, nunca ecoada: o ✗ deles é o esperado, e ecoá-lo
# faria o run.sh contá-lo como falha da suíte.
#
# Roda sem credencial e sem rede: a amostra é arquivo, e o radar é chamado com
# `--amostra`, que não toca o caminho de rede.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

CONFERENCIA='tests/fixtures/board/conferencia.md'
DUBLES="$FIXTURES/board/conferencia-dubles"

afirmar_arquivo "$CONFERENCIA" "existe: $CONFERENCIA"

# ─── 1. A conferência está versionada ───────────────────────────────────────
# É metade do critério da C3, e é verificável: registrada quer dizer no
# repositório, não no terminal de quem a fez.

if git ls-files --error-unmatch "$CONFERENCIA" >/dev/null 2>&1; then
  afirmar 0 'a conferência está versionada, e não no histórico de conversa de ninguém'
else
  afirmar 1 'a conferência está versionada, e não no histórico de conversa de ninguém'
fi

# ─── 2. A conferência de verdade ────────────────────────────────────────────
# O ✓ de cada verificação vem do próprio verificador: a conta refeita, a data
# buscada na amostra, a cobertura fechada e a comparação com o radar.

python3 tests/conferencia/verificar.py

# ─── 3. Os dublês ───────────────────────────────────────────────────────────

# canario <nome-do-dublê> <mensagem-esperada> <descrição>
canario() {
  local nome="$1" esperado="$2" descricao="$3"
  local saida status
  saida="$(python3 tests/conferencia/verificar.py --conferencia "$DUBLES/$nome.md" 2>&1)"
  status=$?
  afirmar_igual '1' "$status" "$nome: o verificador sai 1"
  afirmar_contem "$esperado" "$saida" "$descricao"
}

canario 'numero-errado' \
  '✗ MRD-101: a conta da conferência fecha' \
  'número que não fecha com a própria conta é pego pela subtração refeita'

canario 'data-fora-da-amostra' \
  '✗ MRD-101: a data da conta é a que está na amostra' \
  'conta que fecha sobre data que a amostra não tem é pega'

canario 'issue-sem-linha' \
  '✗ toda issue da amostra tem linha' \
  'issue da amostra sem linha na conferência derruba o caso, e a mensagem diz qual'

canario 'classificacao-errada' \
  'conferido à mão '"'"'🔴'"'"', radar' \
  'classificação que o radar contradiz é pega, com os dois lados na mensagem'

# O dublê da classificação só prova alguma coisa se a conta dele estiver certa:
# caindo antes, na aritmética, ele não teria chegado a comparar com o radar, e a
# asserção acima passaria pelo motivo errado.
saida="$(python3 tests/conferencia/verificar.py \
  --conferencia "$DUBLES/classificacao-errada.md" 2>&1)"
afirmar_nao_contem '✗ MRD-103: a conta' "$saida" \
  'e ele chega mesmo à comparação: a conta dele fecha, só a classificação é que não'

# ─── 4. A conferência não depende do relógio ────────────────────────────────
# A data de referência sai do próprio arquivo. Se o verificador lesse o relógio,
# a conferência valeria por um dia só — e passaria a falhar sozinha no dia
# seguinte, que é o defeito que a C2 tirou do radar.

afirmar_contem '<!-- referencia:' "$(cat "$CONFERENCIA")" \
  'a conferência declara, no próprio arquivo, a data de referência que valeu'

SEM_REFERENCIA="$(mktemp -d)"
trap 'rm -rf "$SEM_REFERENCIA"' EXIT
grep -v '<!-- referencia:' "$CONFERENCIA" >"$SEM_REFERENCIA/conferencia.md"
saida="$(python3 tests/conferencia/verificar.py \
  --conferencia "$SEM_REFERENCIA/conferencia.md" 2>&1)"
status=$?
afirmar_igual '1' "$status" 'conferência sem data de referência sai 1'
afirmar_nao_contem 'o radar devolve JSON' "$saida" \
  'e o radar nem é chamado: sem a data não há o que comparar'
