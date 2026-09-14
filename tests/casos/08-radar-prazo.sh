#!/usr/bin/env bash
#
# O radar de prazo aplica a política e classifica sobre data injetada (TASKS C2).
#
# As três metades do critério de pronto, e onde cada uma é provada aqui:
#
#   1. **A saída tem só os campos que o julgamento usa.** O conjunto de chaves é
#      conferido como conjunto FECHADO — campo novo derruba o caso, e derruba de
#      propósito: coletor que engorda a saída devolve ao laudo o despejo de
#      issue crua que a SPEC §4 existe para impedir.
#   2. **A classificação sai do `.yaml`.** Provado trocando o arquivo, não lendo
#      o script: sobre a mesma amostra e a mesma referência, um dublê de política
#      com a janela mais larga muda um 🟢 para 🟡. Nenhuma linha de script muda.
#   3. **A data de referência é injetável.** Provado com duas referências sobre a
#      mesma amostra: se a classificação não mudasse, o radar estaria lendo o
#      relógio, e a classificação seria intestável.
#
# ⚠️ Nenhuma asserção escreve nome de campo de prazo: os nomes saem da política,
# em execução. Escrevê-los aqui faria `tests/casos/07-prazo.sh` falhar — e faria
# bem, porque este arquivo é script como qualquer outro (decisões 0003).
#
# Roda sem credencial e sem rede: tudo sai de tests/fixtures/board/, e os blocos
# que provam ausência de chamada rodam em `env -i` com um `PATH` sem `curl`.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

RADAR="$RAIZ/.ai/tools/coleta/board-radar.sh"
FIX="$FIXTURES/board"
AMOSTRA="$FIX/amostra.json"
REF='2026-09-14'

afirmar_arquivo "$RADAR" 'existe: .ai/tools/coleta/board-radar.sh'
afirmar_arquivo "$AMOSTRA" 'existe a amostra do board'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SO_BASH="$TMP/so-bash"
BIN_CURL="$TMP/bin-curl"
mkdir -p "$SO_BASH" "$BIN_CURL" "$TMP/sem-politica"
ln -s "$(command -v bash)" "$SO_BASH/bash"
ln -s "$(command -v jq)" "$SO_BASH/jq"
ln -s "$(command -v python3)" "$SO_BASH/python3"
cp "$FIXTURES/credenciais/duble-curl-200.sh" "$BIN_CURL/curl"
chmod +x "$BIN_CURL/curl"

# Os nomes de campo vêm da política, nunca deste arquivo.
politica() { python3 "$RAIZ/.ai/tools/lib/politica.py" "$RAIZ/.ai/politicas/prazo.yaml"; }
campo_de() { politica | jq -r "$1"; }

CAMPO_CLIENTE_1="$(campo_de '.origens.cliente.campos[0]')"
CAMPO_INTERNO_1="$(campo_de '.origens.interno.campos[0]')"
CAMPO_CORROBORACAO="$(campo_de '.corroboracao.campo')"

# ─── 1. A saída, sobre a amostra e com a referência congelada ───────────────

SAIDA="$(SCULLY_AGORA="$REF" bash "$RADAR" --amostra "$AMOSTRA" 2>"$TMP/erro")"
status=$?
afirmar_igual '0' "$status" 'o radar sai 0 sobre a amostra'
if printf '%s' "$SAIDA" | jq -e . >/dev/null 2>&1; then
  afirmar 0 'e a saída é JSON válido'
else
  afirmar 1 'e a saída é JSON válido'
  cat "$TMP/erro"
fi

item() { printf '%s' "$SAIDA" | jq -r --arg k "$1" ".itens[] | select(.chave == \$k) | $2"; }

afirmar_igual "$REF" "$(printf '%s' "$SAIDA" | jq -r .referencia)" \
  'a saída declara a data de referência que valeu'

# ─── 2. Só os campos que o julgamento usa ───────────────────────────────────
# Conjunto fechado, nos dois níveis. É a asserção que envelhece bem: ela falha
# tanto quando alguém tira um campo quanto quando alguém acrescenta um.

afirmar_igual 'examinados referencia sob_controle total truncado itens' \
  "$(printf '%s' "$SAIDA" | jq -r 'keys_unsorted - ["itens"] | sort | join(" ")') itens" \
  'o topo da saída tem exatamente os campos declarados'

esperado_item='base campo_do_prazo chave classificacao dias_de_atraso dias_de_idade prazo_efetivo'
afirmar_igual "$esperado_item" \
  "$(printf '%s' "$SAIDA" | jq -r '[.itens[] | keys | join(" ")] | unique | join(" | ")')" \
  'todo item tem exatamente os campos que o julgamento usa, e nenhum a mais'

# ─── 3. A precedência é a da política ───────────────────────────────────────

# Canário: MRD-101 só prova precedência se tiver MESMO os dois campos
# preenchidos. Sem isto a asserção seguinte passaria por vacuidade.
dois_preenchidos="$(jq -r --arg a "$CAMPO_CLIENTE_1" --arg b "$CAMPO_INTERNO_1" '
  (.names | to_entries | map({key: .value, value: .key}) | from_entries) as $id
  | .issues[] | select(.key == "MRD-101")
  | (.fields[$id[$a]] != null) and (.fields[$id[$b]] != null)' "$AMOSTRA")"
afirmar_igual 'true' "$dois_preenchidos" \
  'a amostra tem MRD-101 com os dois primeiros campos preenchidos (o canário da precedência)'

afirmar_igual "$CAMPO_CLIENTE_1" "$(item MRD-101 .campo_do_prazo)" \
  'origem de cliente: vale o primeiro campo da lista, e não o segundo'
afirmar_igual '9' "$(item MRD-101 .dias_de_atraso)" \
  'e o atraso é o que se confere à mão sobre a data de referência'
afirmar_igual '🔴' "$(item MRD-101 .classificacao)" 'prazo vencido é 🔴'

# Canário do resíduo de triagem: MRD-102 é interno E tem o campo de cliente
# preenchido. A lista de `interno` o exclui de propósito — usá-lo reportaria ao
# time um prazo que ninguém prometeu a ninguém.
residuo="$(jq -r --arg a "$CAMPO_CLIENTE_1" '
  (.names | to_entries | map({key: .value, value: .key}) | from_entries) as $id
  | .issues[] | select(.key == "MRD-102") | .fields[$id[$a]] != null' "$AMOSTRA")"
afirmar_igual 'true' "$residuo" \
  'a amostra tem, na issue interna, o campo de cliente preenchido (o canário do resíduo)'
afirmar_igual "$CAMPO_INTERNO_1" "$(item MRD-102 .campo_do_prazo)" \
  'origem interna: o campo de promessa externa fica fora, como a política manda'

# ─── 4. O numérico de corroboração corrobora, e não decide ──────────────────
# Na amostra ele aponta o contrário do que a data diz: o board o recalcula na
# própria cadência, e um radar que decidisse por ele reportaria errado.

corrobora="$(jq -r --arg c "$CAMPO_CORROBORACAO" '
  (.names | to_entries | map({key: .value, value: .key}) | from_entries) as $id
  | .issues[] | select(.key == "MRD-101") | .fields[$id[$c]]' "$AMOSTRA")"
if [ "$corrobora" -gt 0 ] 2>/dev/null; then
  afirmar 0 'na amostra, o numérico de corroboração de MRD-101 diz "ainda vai vencer"'
else
  afirmar 1 'na amostra, o numérico de corroboração de MRD-101 diz "ainda vai vencer"'
fi
afirmar_igual '🔴' "$(item MRD-101 .classificacao)" \
  'e o radar classifica pela data mesmo assim: o numérico não decide'

# ─── 5. Origem vazia, origem desconhecida, e o bug que vence hoje ───────────

afirmar_igual '0' "$(item MRD-103 .dias_de_atraso)" \
  'origem vazia cai na origem padrão e é julgada como as outras'
afirmar_igual '🟡' "$(item MRD-103 .classificacao)" \
  'vencer hoje é 🟡, e não 🔴: o prazo de hoje ainda não estourou'
afirmar_igual '🔴' "$(item MRD-107 .classificacao)" \
  'rótulo de origem que a política não conhece cai no padrão — e não some do radar'

# ─── 6. Sem prazo declarado: entra pela idade, e nunca como 🔴 ──────────────

afirmar_igual 'idade' "$(item MRD-104 .base)" 'sem campo preenchido, a base é a idade'
afirmar_igual 'null' "$(item MRD-104 .prazo_efetivo)" 'e não há prazo efetivo a declarar'
afirmar_igual 'null' "$(item MRD-104 .dias_de_atraso)" 'nem atraso: não há promessa a atrasar'
afirmar_igual '44' "$(item MRD-104 .dias_de_idade)" 'a idade é a que se confere à mão'
afirmar_igual '🟡' "$(item MRD-104 .classificacao)" 'idade acima do corte é 🟡'

sem_prazo_vermelho="$(printf '%s' "$SAIDA" |
  jq -r '[.itens[] | select(.base == "idade" and .classificacao == "🔴")] | length')"
afirmar_igual '0' "$sem_prazo_vermelho" \
  'nenhum item de idade é 🔴 — estimativa desta casa não vira promessa estourada'

# ─── 7. O que está sob controle é contado, não listado ──────────────────────
# Contado porque o laudo AFIRMA "prazos sob controle" (SPEC §7); não listado
# porque linha de laudo é cota, e 🟢 não pede linha.

afirmar_igual '2' "$(printf '%s' "$SAIDA" | jq -r .sob_controle)" \
  'o que está sob controle vira contagem'
afirmar_igual '0' "$(printf '%s' "$SAIDA" | jq -r '[.itens[] | select(.classificacao == "🟢")] | length')" \
  'e não entra na lista de itens'
afirmar_igual '7' "$(printf '%s' "$SAIDA" | jq -r '.sob_controle + (.itens | length)')" \
  'todo bug da amostra foi julgado: nenhum sumiu pelo caminho'

afirmar_igual '🔴' "$(printf '%s' "$SAIDA" | jq -r '.itens[0].classificacao')" \
  'a ordem põe o estourado antes do que vai estourar'

# ─── 8. A amostra menor que o total é marcada, não arredondada ──────────────
# «O tamanho da página não é o total» (SPEC §10): reportar `length` como total
# subnotifica em silêncio.

TRUNCADA="$(SCULLY_AGORA="$REF" bash "$RADAR" --amostra "$FIX/amostra-truncada.json")"
afirmar_igual 'true' "$(printf '%s' "$TRUNCADA" | jq -r .truncado)" \
  'amostra menor que o total declarado sai marcada como truncada'
afirmar_igual '99' "$(printf '%s' "$TRUNCADA" | jq -r .total)" \
  'e o total é o que o board declara, não o tamanho da página'
afirmar_igual '1' "$(printf '%s' "$TRUNCADA" | jq -r .examinados)" \
  'com o tamanho da amostra dito ao lado'

# ─── 9. A data de referência é injetável ────────────────────────────────────
# Duas referências, a mesma amostra. Não mudando nada, o radar está lendo o
# relógio — e a classificação é intestável.

OUTRA="$(SCULLY_AGORA='2026-09-01' bash "$RADAR" --amostra "$AMOSTRA")"
antes="$(printf '%s' "$OUTRA" | jq -r '.itens[] | select(.chave == "MRD-101") | .classificacao')"
afirmar_igual '' "$antes" 'com a referência duas semanas antes, o 🔴 de MRD-101 não existe'
afirmar_igual '5' "$(printf '%s' "$OUTRA" | jq -r .sob_controle)" \
  'e a contagem de sob controle muda junto — a classificação depende da data injetada'

HOJE="$(bash "$RADAR" --amostra "$AMOSTRA" | jq -r .referencia)"
afirmar_igual "$(date -u +%Y-%m-%d)" "$HOJE" \
  'sem a variável, a referência é hoje — a injeção é opção, não obrigação'

# ─── 10. O limiar sai do arquivo, e não do script ───────────────────────────
# A prova é trocar o arquivo. Ler o script provaria menos: um número pode estar
# escrito de várias formas, e o que importa é de onde o radar o tira.

LARGA="$(SCULLY_AGORA="$REF" SCULLY_POLITICAS_DIR="$FIX/politica-janela-larga" \
  bash "$RADAR" --amostra "$AMOSTRA")"
afirmar_igual '1' "$(printf '%s' "$LARGA" | jq -r .sob_controle)" \
  'com a janela do 🟡 mais larga, um 🟢 deixa de ser 🟢 — sem tocar em script'
afirmar_igual '🟡' \
  "$(printf '%s' "$LARGA" | jq -r '.itens[] | select(.chave == "MRD-105") | .classificacao')" \
  'e é o bug de prazo distante que passa a aparecer'

# ─── 11. O que o radar não entende, ele não julga ───────────────────────────
# Data ilegível tratada como "sem prazo" mandaria a issue para o fallback, e um
# prazo de verdade seria reportado como idade.

saida="$(SCULLY_AGORA="$REF" bash "$RADAR" --amostra "$FIX/amostra-data-ilegivel.json" 2>&1)"
status=$?
afirmar_igual '1' "$status" 'data ilegível no campo de prazo faz sair 1'
afirmar_contem 'MRD-301' "$saida" 'e a recusa diz qual issue'
afirmar_nao_contem 'ontem de manhã' "$saida" \
  'sem repassar o valor: conteúdo de board não se ecoa (SPEC §9)'
afirmar_nao_contem '"itens"' "$saida" 'e nada de saída pela metade, que pareceria resposta'

# ─── 12. Política ausente falha declarando ──────────────────────────────────

saida="$(SCULLY_AGORA="$REF" SCULLY_POLITICAS_DIR="$TMP/sem-politica" \
  bash "$RADAR" --amostra "$AMOSTRA" 2>&1)"
status=$?
afirmar_igual '1' "$status" 'política ausente faz sair 1, em vez de assumir um número'
afirmar_contem 'política ausente' "$saida" 'e a mensagem diz que é a política que falta'

# ─── 13. Ferramenta ausente falha, não pula ─────────────────────────────────

saida="$(env -i PATH="$SO_BASH" SCULLY_SEM_ENV=1 SCULLY_AGORA="$REF" \
  bash "$RADAR" --amostra "$AMOSTRA" 2>&1)"
status=$?
afirmar_igual '0' "$status" 'com --amostra o radar não precisa de curl: o PATH sem curl passa'
afirmar_contem '"referencia"' "$saida" 'e devolve a saída normalmente — nenhuma chamada foi feita'

SO_SHELL="$TMP/so-shell"
mkdir -p "$SO_SHELL"
ln -s "$(command -v bash)" "$SO_SHELL/bash"
saida="$(env -i PATH="$SO_SHELL" SCULLY_SEM_ENV=1 bash "$RADAR" --amostra "$AMOSTRA" 2>&1)"
status=$?
afirmar_igual '1' "$status" 'jq ausente faz sair 1'
afirmar_contem 'jq não está instalado' "$saida" 'e diz que nada foi coletado'

# ─── 14. Sem credencial: falha declarada, e nenhuma chamada ─────────────────
# Fonte não configurada NÃO é fila vazia. O estado `nao_integrada` na própria
# saída é a task C4; até lá, o que não pode é virar `[]`.

rm -f "$TMP/argv" "$TMP/stdin"
saida="$(env -i PATH="$BIN_CURL:/usr/bin:/bin" SCULLY_SEM_ENV=1 \
  DUBLE_ARGV="$TMP/argv" DUBLE_STDIN="$TMP/stdin" bash "$RADAR" 2>&1)"
status=$?
afirmar_igual '1' "$status" 'sem credencial e sem amostra, o radar sai 1'
afirmar_contem 'falta BOARD_BASE_URL' "$saida" 'e diz exatamente qual variável falta'
afirmar_nao_contem '"itens"' "$saida" 'e não devolve fila vazia no lugar da fonte'
if [ -e "$TMP/argv" ]; then
  afirmar 1 'sem credencial, nenhuma chamada é tentada'
else
  afirmar 0 'sem credencial, nenhuma chamada é tentada'
fi

# ─── 15. O segredo não aparece na saída ─────────────────────────────────────
# `.invalido` é TLD reservado (RFC 2606) e o sentinela se anuncia como o que é.

SENTINELA='sentinela-nao-deve-vazar-c2a7f1'
saida="$(env -i PATH="$BIN_CURL:/usr/bin:/bin" SCULLY_SEM_ENV=1 SCULLY_AGORA="$REF" \
  BOARD_BASE_URL="https://sentinela-host.exemplo.invalido" \
  BOARD_EMAIL='plantao@exemplo.invalido' \
  BOARD_API_TOKEN="$SENTINELA" BOARD_PROJETO='MRD' \
  bash "$RADAR" --amostra "$AMOSTRA" 2>&1)"
afirmar_nao_contem "$SENTINELA" "$saida" 'nenhum caractere do segredo aparece na saída'
afirmar_nao_contem 'sentinela-host' "$saida" \
  'nem o host, que identifica a instância de quem clonou'
