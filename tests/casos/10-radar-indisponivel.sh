#!/usr/bin/env bash
#
# O radar insiste, desiste declarando, e nunca devolve fila vazia (TASKS C4).
#
# As quatro metades do critério de pronto, e onde cada uma é provada aqui:
#
#   1. **Duas novas tentativas em erro transitório, com espera crescente.**
#      Contadas no dublê de `curl`: um 500 sempre vira exatamente três
#      chamadas. Que a espera existe e CRESCE é medido no relógio, no bloco 6 —
#      stderr que anuncia uma espera que não acontece passaria em qualquer
#      asserção de texto.
#   2. **Persistindo, saída marcada `indisponivel: true`, e nunca lista vazia.**
#      A ausência de `itens`, `total`, `examinados` e `sob_controle` é asserção
#      própria: é ela que impede o estado de virar número.
#   3. **Sem credencial, saída marcada `nao_integrada: true`.** Sem nenhuma
#      chamada tentada, o que também é conferido.
#   4. **Os dois estados são distinguíveis.** Duas chaves, e não dois valores de
#      uma — e o bloco 7 compara as duas saídas lado a lado.
#
# ⚠️ **Por que o corpo de erro do dublê é JSON bem formado:** um coletor que
# ignorasse o código HTTP o normalizaria sem reclamar — sem `issues`, a conta dá
# zero, o estourado vira fila vazia e nada falha. O bloco 2 fecha essa porta
# afirmando o que NÃO está na saída.
#
# Roda sem credencial e sem rede: o `curl` do PATH é o dublê de
# tests/fixtures/board/, e tudo roda em `env -i`.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

RADAR="$RAIZ/.ai/tools/coleta/board-radar.sh"
FIX="$FIXTURES/board"
AMOSTRA="$FIX/amostra.json"
REF='2026-09-14'

# `.invalido` é TLD reservado (RFC 2606), e o sentinela se anuncia como o que é.
SENTINELA='sentinela-nao-deve-vazar-c4b2e9'
HOST_FALSO='https://sentinela-host.exemplo.invalido'

afirmar_arquivo "$FIX/duble-curl.sh" 'existe o dublê de curl com sequência'
afirmar_arquivo "$FIX/politica-sem-espera/coleta.yaml" 'existe o dublê de política sem espera'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
cp "$FIX/duble-curl.sh" "$BIN/curl"
chmod +x "$BIN/curl"

# Cada dublê de política traz só o `coleta.yaml`: o `prazo.yaml` é o de verdade,
# copiado ao lado. Duplicá-lo em cada dublê criaria uma segunda cópia da
# precedência de campos, que diverge da primeira em semanas (decisões 0003).
politicas_com() {
  local destino="$TMP/politicas-$1"
  mkdir -p "$destino"
  cp "$RAIZ/.ai/politicas/prazo.yaml" "$destino/prazo.yaml"
  [ -n "${2:-}" ] && cp "$2" "$destino/coleta.yaml"
  printf '%s' "$destino"
}

SEM_ESPERA="$(politicas_com sem-espera "$FIX/politica-sem-espera/coleta.yaml")"
ESPERA_CURTA="$(politicas_com espera-curta "$FIX/politica-espera-curta/coleta.yaml")"
UMA_TENTATIVA="$(politicas_com uma-tentativa "$FIX/politica-uma-tentativa/coleta.yaml")"
SEM_COLETA="$(politicas_com sem-coleta)"

# rodar <dir-de-política> <sequência de respostas> [corpo do 2xx]
# Deixa em SAIDA, ERRO, STATUS e CHAMADAS. Credencial sempre presente: o que
# varia entre os blocos é o que o board responde, não o que está configurado.
rodar() {
  rm -f "$TMP/contador" "$TMP/erro"
  SAIDA="$(env -i PATH="$BIN:/usr/bin:/bin" SCULLY_SEM_ENV=1 SCULLY_AGORA="$REF" \
    SCULLY_POLITICAS_DIR="$1" \
    BOARD_BASE_URL="$HOST_FALSO" BOARD_EMAIL='plantao@exemplo.invalido' \
    BOARD_API_TOKEN="$SENTINELA" BOARD_PROJETO='MRD' \
    DUBLE_SEQUENCIA="$2" DUBLE_CORPO="${3:-}" DUBLE_CONTADOR="$TMP/contador" \
    bash "$RADAR" 2>"$TMP/erro")"
  STATUS=$?
  ERRO="$(cat "$TMP/erro" 2>/dev/null)"
  # Atribuída no começo da linha, e não depois de um `then`: é assim que o
  # verificador do inventário reconhece variável de trabalho deste arquivo em
  # vez de entrada de ambiente não documentada (TASKS B2).
  CHAMADAS=0
  [ -f "$TMP/contador" ] && CHAMADAS="$(wc -l <"$TMP/contador")"
}

campo() { printf '%s' "$SAIDA" | jq -r "$1"; }

# ─── 1. 5xx que não passa: três chamadas, e desiste declarando ──────────────

rodar "$SEM_ESPERA" '500'
afirmar_igual '0' "$STATUS" 'o radar sai 0: reportar a falha é ter conseguido responder'
afirmar_igual '3' "$CHAMADAS" 'a primeira chamada mais as duas retentativas da SPEC §7'
afirmar_igual 'true' "$(campo .indisponivel)" 'e a saída vem marcada como indisponível'
afirmar_igual 'false' "$(campo .nao_integrada)" 'e não como não integrada: a fonte existe, caiu'
afirmar_igual "$REF" "$(campo .referencia)" 'a saída ainda declara a data em que se tentou'

# ─── 2. O estado não vira número ────────────────────────────────────────────
# A asserção é sobre o que NÃO está lá. `itens: []` se lê como "não havia
# nada", e `total: 0` como "a fila está vazia" — as duas afirmações que a
# SPEC §1 proíbe fazer sem ter lido fonte nenhuma.

for chave in itens total examinados sob_controle truncado; do
  afirmar_igual 'false' "$(campo "has(\"$chave\")")" \
    "a saída de fonte caída não tem \`$chave\`: estado não vira número"
done
afirmar_igual 'referencia indisponivel nao_integrada' "$(campo 'keys_unsorted | join(" ")')" \
  'e tem exatamente as três chaves do estado, nessa ordem'
afirmar_igual 'null' "$(campo .itens)" \
  'quem pedir `.itens` lê null, que não se confunde com lista vazia'

# ─── 3. Diagnóstico é log, e fica no stderr ─────────────────────────────────
# «Nada de diagnóstico no laudo» (SPEC §7): código HTTP é log da execução.

afirmar_nao_contem '500' "$SAIDA" 'nenhum código HTTP na saída que o laudo lê'
afirmar_contem 'HTTP 500' "$ERRO" 'e o código está no stderr, onde é log da execução'
afirmar_contem 'tentativa 1 de 3' "$ERRO" 'o stderr diz em que tentativa falhou'
afirmar_contem 'indisponível' "$ERRO" 'e diz o que fez com isso'
afirmar_nao_contem "$SENTINELA" "$SAIDA$ERRO" 'nenhum caractere do segredo aparece'
afirmar_nao_contem 'sentinela-host' "$SAIDA$ERRO" \
  'nem o host, que identifica a instância de quem clonou'

# ─── 4. Timeout também é transitório ────────────────────────────────────────

rodar "$SEM_ESPERA" 'timeout'
afirmar_igual '3' "$CHAMADAS" 'timeout é transitório: três chamadas, como no 5xx'
afirmar_igual 'true' "$(campo .indisponivel)" 'e persistindo sai indisponível'
afirmar_contem 'tempo-limite' "$ERRO" 'o stderr diz que foi o tempo-limite'

# ─── 5. O que não é transitório não se repete ───────────────────────────────
# Repetir um 403 é gastar a janela da ronda num erro que não muda sozinho — e
# atrasar o laudo das outras fontes.

rodar "$SEM_ESPERA" '403'
afirmar_igual '1' "$CHAMADAS" '403 não é transitório: uma chamada, sem retentativa'
afirmar_igual 'true' "$(campo .indisponivel)" 'e ainda assim a fonte sai como indisponível'
afirmar_igual 'false' "$(campo .nao_integrada)" \
  'credencial recusada é fonte caída, não lacuna: configurada está'

# ─── 6. A retentativa recupera, e a espera cresce ───────────────────────────
# Transitório que passa tem de virar coleta de verdade — senão a retentativa
# está só adiando a mesma falha.

rodar "$SEM_ESPERA" '429 500 200' "$AMOSTRA"
afirmar_igual '3' "$CHAMADAS" 'duas falhas transitórias e a terceira responde'
afirmar_igual 'false' "$(campo .indisponivel)" 'a saída recuperada não vem marcada'
afirmar_igual '7' "$(campo .total)" 'e traz o total da amostra, conferido no caso 08'
afirmar_igual '5' "$(campo '.itens | length')" 'com os mesmos itens de sempre'

inicio=$SECONDS
rodar "$ESPERA_CURTA" '500'
decorrido=$((SECONDS - inicio))
afirmar_contem 'nova tentativa em 1s' "$ERRO" 'a primeira espera é a do arquivo'
afirmar_contem 'nova tentativa em 2s' "$ERRO" 'e a segunda é maior: a espera cresce'
if [ "$decorrido" -ge 3 ]; then
  afirmar 0 "a espera acontece de verdade: ${decorrido}s de relógio, 1s + 2s"
else
  afirmar 1 "a espera acontece de verdade (esperado >= 3s, medido ${decorrido}s)"
fi

# ─── 7. Sem credencial: lacuna, e não incidente ─────────────────────────────

rm -f "$TMP/contador"
SEM_CREDENCIAL="$(env -i PATH="$BIN:/usr/bin:/bin" SCULLY_SEM_ENV=1 SCULLY_AGORA="$REF" \
  SCULLY_POLITICAS_DIR="$SEM_ESPERA" DUBLE_CONTADOR="$TMP/contador" \
  bash "$RADAR" 2>"$TMP/erro")"
status=$?
erro="$(cat "$TMP/erro")"

afirmar_igual '0' "$status" 'sem credencial o radar sai 0, declarando a lacuna'
afirmar_igual 'true' "$(printf '%s' "$SEM_CREDENCIAL" | jq -r .nao_integrada)" \
  'e a saída vem marcada como não integrada'
afirmar_igual 'false' "$(printf '%s' "$SEM_CREDENCIAL" | jq -r .indisponivel)" \
  'e NÃO como indisponível: fonte adiada não é fonte caída (SPEC §7)'
afirmar_igual 'false' "$(printf '%s' "$SEM_CREDENCIAL" | jq -r 'has("itens")')" \
  'a lacuna também não vira lista vazia'
afirmar_contem 'falta BOARD_BASE_URL' "$erro" 'o stderr diz exatamente qual variável falta'
if [ -e "$TMP/contador" ]; then
  afirmar 1 'sem credencial, nenhuma chamada é tentada'
else
  afirmar 0 'sem credencial, nenhuma chamada é tentada'
fi

# Lado a lado: é a distinção que a SPEC §7 exige, e ela só vale se as duas
# saídas forem mesmo diferentes uma da outra.
rodar "$SEM_ESPERA" '500'
if [ "$SAIDA" != "$SEM_CREDENCIAL" ]; then
  afirmar 0 'as duas saídas de falha são distinguíveis uma da outra'
else
  afirmar 1 'as duas saídas de falha são distinguíveis uma da outra'
fi

# ─── 8. Quantas tentativas sai do arquivo, não do script ────────────────────
# A prova é trocar o arquivo, como no limiar de classificação do caso 08: com o
# `2` literal no coletor, este dublê não mudaria contagem nenhuma.

rodar "$UMA_TENTATIVA" '500'
afirmar_igual '1' "$CHAMADAS" \
  'com tentativas_extras: 0, o radar chama uma vez — sem tocar em script'
afirmar_igual 'true' "$(campo .indisponivel)" 'e desiste declarando, como antes'

# ─── 9. Política de coleta ausente falha, não assume número ─────────────────

rodar "$SEM_COLETA" '500'
afirmar_igual '1' "$STATUS" 'política de coleta ausente faz sair 1'
afirmar_igual '' "$SAIDA" 'e não devolve estado nenhum: isto não é fonte caída'
afirmar_contem 'política de coleta ausente' "$ERRO" 'a mensagem diz o que falta'
afirmar_igual '0' "$CHAMADAS" 'e nada é chamado antes de saber quanto insistir'

# ─── 10. Com --amostra não se exige a política de coleta ────────────────────
# Não há chamada a repetir; exigi-la aqui obrigaria todo dublê de política da
# suíte a trazer um arquivo que o caminho exercitado não usa.

saida="$(env -i PATH="$BIN:/usr/bin:/bin" SCULLY_SEM_ENV=1 SCULLY_AGORA="$REF" \
  SCULLY_POLITICAS_DIR="$SEM_COLETA" bash "$RADAR" --amostra "$AMOSTRA" 2>&1)"
status=$?
afirmar_igual '0' "$status" 'o caminho da amostra não precisa da política de coleta'
afirmar_contem '"total": 7' "$saida" 'e devolve a saída de sempre'
