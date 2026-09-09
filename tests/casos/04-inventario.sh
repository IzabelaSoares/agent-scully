#!/usr/bin/env bash
#
# O `.env.example` é o inventário das credenciais: o que um script lê, ele
# documenta — com as cinco informações e sem nenhum valor.
#
# A divergência entre o que o script lê e o que o exemplo documenta é o defeito
# mais comum deste tipo de projeto e o mais chato de diagnosticar: ele se
# manifesta como "funciona na sua máquina" (TASKS B2).

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

afirmar_arquivo ".env.example" "existe: .env.example"
afirmar_arquivo "tests/inventario/internas.txt" "existe a lista de variáveis internas"

python3 tests/inventario/verificar.py

# ─── Os canários ────────────────────────────────────────────────────────────
# Um verificador que só roda sobre árvore limpa não prova nada sobre o dia em
# que a árvore não estiver limpa. Cada canário quebra UMA coisa, e a saída é
# capturada para que os ✗ dele não entrem na contagem da suíte.

DUBLE="$FIXTURES/inventario/coletor-fake.sh"
EXEMPLO_INCOMPLETO="$FIXTURES/inventario/exemplo-incompleto.env"

afirmar_arquivo "$DUBLE" "existe o dublê de script"
afirmar_arquivo "$EXEMPLO_INCOMPLETO" "existe o dublê de .env.example incompleto"

if saida="$(python3 tests/inventario/verificar.py --script "$DUBLE" 2>&1)"; then
  afirmar 1 'variável lida por script e ausente do .env.example faz falhar'
else
  afirmar 0 'variável lida por script e ausente do .env.example faz falhar'
fi
afirmar_contem 'FIXTURE_FONTE_API_TOKEN' "$saida" \
  'e a falha diz qual variável ficou de fora'
afirmar_contem 'coletor-fake.sh' "$saida" \
  'e em que arquivo ela é lida'

if saida="$(python3 tests/inventario/verificar.py \
  --exemplo "$EXEMPLO_INCOMPLETO" --script "$DUBLE" 2>&1)"; then
  afirmar 1 'seção sem uma das cinco informações faz falhar'
else
  afirmar 0 'seção sem uma das cinco informações faz falhar'
fi
afirmar_contem 'validade' "$saida" 'e a falha diz qual informação falta'

if saida="$(python3 tests/inventario/verificar.py \
  --exemplo "$FIXTURES/inventario/exemplo-com-valor.env" --script "$DUBLE" 2>&1)"; then
  afirmar 1 'valor preenchido onde o nome diz segredo faz falhar'
else
  afirmar 0 'valor preenchido onde o nome diz segredo faz falhar'
fi
afirmar_contem 'FIXTURE_FONTE_API_TOKEN' "$saida" 'e diz qual variável está preenchida'

# A lista de exceções tem que ser capaz de falhar: uma lista que cobrisse tudo
# passaria sempre, e é o mesmo modo de falha de uma lista vazia na sanitização.
vazia="$(mktemp)"
trap 'rm -f "$vazia"' EXIT
printf '# sem nenhuma entrada\n' >"$vazia"
if saida="$(python3 tests/inventario/verificar.py --internas "$vazia" 2>&1)"; then
  afirmar 1 'internas.txt vazio faz falhar (lista que não protege nada)'
else
  afirmar 0 'internas.txt vazio faz falhar (lista que não protege nada)'
fi
