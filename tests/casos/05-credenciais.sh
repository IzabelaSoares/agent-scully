#!/usr/bin/env bash
#
# A verificação de credenciais reporta ✅ / ❌ / 🚧 e **não imprime segredo** —
# nem quando a ferramenta de rede devolve o segredo na própria saída (TASKS B3).
#
# O caso grava um sentinela em cada variável de credencial e falha se qualquer
# caractere dele aparecer na saída. Duas asserções são canário e existem para
# que as outras não sejam vazias: o dublê que vaza precisa vazar mesmo, e o
# segredo precisa mesmo chegar ao dublê — um teste de negação sobre uma chamada
# que nunca aconteceu passa sempre e não protege nada.
#
# Roda sem credencial e sem rede: `curl` é um dublê no PATH, e cada execução vai
# num ambiente limpo (`env -i`), o que impede a credencial de verdade da máquina
# de vazar para dentro do teste — e o teste de sair para a rede.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

SCRIPT="$RAIZ/ops/verificar-credenciais.sh"
FIX="$FIXTURES/credenciais"

# Nada aqui parece credencial de verdade: `.invalido` é TLD reservado (RFC 2606)
# e o sentinela se anuncia como o que é.
SENTINELA='sentinela-nao-deve-vazar-9f3a1c'
HOST_SENTINELA='sentinela-host.exemplo.invalido'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BIN_OK="$TMP/bin-200"
BIN_VAZA="$TMP/bin-vazando"
SO_BASH="$TMP/so-bash"
mkdir -p "$BIN_OK" "$BIN_VAZA" "$SO_BASH" "$TMP/sem-politica"
cp "$FIX/duble-curl-200.sh" "$BIN_OK/curl"
cp "$FIX/duble-curl-vazando.sh" "$BIN_VAZA/curl"
chmod +x "$BIN_OK/curl" "$BIN_VAZA/curl"
ln -s "$(command -v bash)" "$SO_BASH/bash"

# Trocada nos dois últimos blocos, para exercitar política ausente e política
# incompleta. Volta ao dublê bom logo depois.
POLITICAS="$FIX/politica"

CREDENCIAIS=(
  "BOARD_BASE_URL=https://$HOST_SENTINELA"
  "BOARD_EMAIL=plantao@exemplo.invalido"
  "BOARD_API_TOKEN=$SENTINELA"
  "SLACK_WEBHOOK_URL=https://$HOST_SENTINELA/servicos/$SENTINELA"
  "APM_BASE_URL=https://$HOST_SENTINELA"
  "APM_API_TOKEN=$SENTINELA"
  "LANGFUSE_HOST=https://$HOST_SENTINELA"
  "LANGFUSE_PUBLIC_KEY=$SENTINELA"
  "LANGFUSE_SECRET_KEY=$SENTINELA"
  "HELPDESK_BASE_URL=https://$HOST_SENTINELA"
  "HELPDESK_EMAIL=suporte@exemplo.invalido"
  "HELPDESK_API_TOKEN=$SENTINELA"
  "GH_TOKEN=$SENTINELA"
  "ALVO_REPO=pessoa/alvo-sentinela"
)

# rodar <dir-com-o-dublê-de-curl> [VAR=valor...] — ambiente limpo, stdout+stderr.
rodar() {
  local bin="$1"
  shift
  env -i PATH="$bin:/usr/bin:/bin" \
    SCULLY_SEM_ENV=1 \
    SCULLY_POLITICAS_DIR="$POLITICAS" \
    DUBLE_ARGV="$TMP/argv" \
    DUBLE_STDIN="$TMP/stdin" \
    "$@" bash "$SCRIPT" 2>&1
}

afirmar_arquivo "$SCRIPT" "existe: ops/verificar-credenciais.sh"
afirmar_arquivo "$RAIZ/.ai/politicas/verificacao.yaml" \
  "existe a política com o tempo-limite"
afirmar_arquivo "$FIX/duble-curl-200.sh" "existe o dublê de curl que responde 200"
afirmar_arquivo "$FIX/duble-curl-vazando.sh" "existe o dublê de curl que vaza"

# ─── 1. Sem credencial: lacuna, e nenhuma chamada ───────────────────────────
# "Não configurada" não é "recusada" (SPEC §11), e a diferença aparece no
# marcador e no status de saída.

rm -f "$TMP/argv" "$TMP/stdin"
saida="$(rodar "$BIN_OK")"
status=$?

afirmar_igual '2' "$status" 'sem credencial nenhuma, sai 2 (lacuna) e não 1 (falha)'
afirmar_nao_contem '✅' "$saida" 'nada é dado como verificado quando não há o que verificar'
afirmar_contem '🚧 board' "$saida" 'o board aparece como lacuna'
afirmar_contem 'não configurada — falta BOARD_BASE_URL BOARD_EMAIL BOARD_API_TOKEN' \
  "$saida" 'e a lacuna diz exatamente qual variável falta'
if [ -e "$TMP/argv" ]; then
  afirmar 1 'sem credencial, nenhuma chamada é tentada'
else
  afirmar 0 'sem credencial, nenhuma chamada é tentada'
fi

# ─── 2. Tudo preenchido, dublê respondendo 200 ──────────────────────────────

rm -f "$TMP/argv" "$TMP/stdin"
saida="$(rodar "$BIN_OK" "${CREDENCIAIS[@]}")"
status=$?

afirmar_igual '2' "$status" 'a lacuna da fonte não integrada sobrevive ao 200 das outras'
afirmar_contem '✅ board' "$saida" 'o board verificado aparece como verificado'
afirmar_contem '✅ langfuse' "$saida" 'o langfuse também'
afirmar_contem '✅ github' "$saida" 'o github também'
afirmar_nao_contem "$SENTINELA" "$saida" \
  'nenhum caractere do segredo aparece na saída do caminho feliz'
afirmar_nao_contem "$HOST_SENTINELA" "$saida" \
  'nem o host, que identifica a instância de quem clonou'

# Canário: sem isto, a asserção acima passaria por a chamada nunca ter ocorrido.
afirmar_contem "$SENTINELA" "$(cat "$TMP/stdin")" \
  'o dublê recebeu mesmo o segredo — a asserção anterior não é vazia'
afirmar_nao_contem "$SENTINELA" "$(cat "$TMP/argv")" \
  'o segredo não vai por argumento de processo, que qualquer `ps` leria'

# Fonte adiada é lacuna com motivo, e o motivo diz em que etapa ela chega.
afirmar_contem 'Etapa 3' "$saida" 'o slack diz por que não é verificável aqui'
afirmar_contem 'Etapa 6' "$saida" 'o apm diz em que etapa é integrado'
afirmar_contem 'Etapa 8' "$saida" 'o helpdesk também'

# ─── 3. O dublê que vaza: o segredo volta pela saída do curl ────────────────

eco="$(printf 'config com %s\n' "$SENTINELA" |
  env DUBLE_STATUS=7 "$FIX/duble-curl-vazando.sh" 2>&1)"
afirmar_contem "$SENTINELA" "$eco" \
  'o dublê que vaza vaza mesmo — senão o bloco inteiro abaixo não prova nada'

rm -f "$TMP/argv" "$TMP/stdin"
saida="$(rodar "$BIN_VAZA" DUBLE_STATUS=7 "${CREDENCIAIS[@]}")"
status=$?

afirmar_igual '1' "$status" 'credencial configurada que não passa sai 1 (falha)'
afirmar_contem '❌ board' "$saida" 'a falha se anuncia, com marcador próprio'
afirmar_contem 'não conectou ao host' "$saida" 'e com o motivo'
afirmar_nao_contem "$SENTINELA" "$saida" \
  'o segredo não vaza nem quando o curl o devolve na própria saída'
afirmar_nao_contem "$HOST_SENTINELA" "$saida" \
  'o host tampouco, nem em caso de erro'
afirmar_nao_contem 'ARGS:' "$saida" \
  'a saída do curl não é repassada: o motivo é escolhido pelo script'

# ─── 3.1 O que o valor da credencial pode conter ────────────────────────────
# O segredo vira uma linha de arquivo de configuração do curl. Duas formas de
# valor quebram esse formato, e cada uma quebra de um jeito diferente.

# Aspa dentro do valor é legal, e sem escape ela fecharia a aspa da opção: o
# curl reportaria um erro que não é o erro que existe.
rm -f "$TMP/argv" "$TMP/stdin"
COM_ASPA="tem\"aspa-$SENTINELA"
saida="$(rodar "$BIN_OK" "${CREDENCIAIS[@]}" "GH_TOKEN=$COM_ASPA")"
afirmar_contem '✅ github' "$saida" 'token com aspa no meio não atrapalha a verificação'
# No arquivo de configuração do curl a aspa aparece escapada — é assim que ela
# chega inteira ao outro lado, em vez de fechar a opção pela metade.
afirmar_contem "tem\\\"aspa-$SENTINELA" "$(cat "$TMP/stdin")" \
  'e chega à ferramenta com a aspa escapada, não truncada nela'
afirmar_nao_contem "$SENTINELA" "$saida" 'e continua fora da saída'

# Quebra de linha viraria OUTRA opção — inclusive outra `url`, que mandaria a
# credencial para outro host. É recusa antes de chamar, não saneamento.
rm -f "$TMP/argv" "$TMP/stdin"
saida="$(rodar "$BIN_OK" "${CREDENCIAIS[@]}" "GH_TOKEN=quebra
url = \"https://outro.exemplo.invalido\"")"
status=$?
afirmar_igual '1' "$status" 'valor com quebra de linha é falha'
afirmar_contem 'quebra de linha — recusado sem chamar' "$saida" \
  'e a recusa acontece antes de a chamada sair'
# As outras fontes seguem sendo chamadas; o que não pode é a linha injetada
# aparecer em chamada nenhuma — os dublês acumulam tudo o que receberam.
afirmar_nao_contem 'outro.exemplo.invalido' "$(cat "$TMP/stdin")" \
  'a url injetada no valor não chegou a chamada nenhuma'

# ─── 4. O tempo-limite sai da política, não de literal em script ────────────

saida="$(rodar "$BIN_VAZA" DUBLE_STATUS=28 "${CREDENCIAIS[@]}")"
afirmar_contem 'estourou o tempo-limite de 7s' "$saida" \
  'o motivo distingue tempo esgotado, e cita o limiar que veio do dublê de política'
afirmar_contem 'tempo-limite: 7s' "$saida" \
  'o rodapé diz qual tempo-limite valeu, e de que arquivo ele saiu'

if grep -Eq -- '--max-time[= ]+[0-9]' "$SCRIPT"; then
  afirmar 1 'o tempo-limite não está literal no script (SPEC §9.1)'
else
  afirmar 0 'o tempo-limite não está literal no script (SPEC §9.1)'
fi

# ─── 5. Política ausente ou incompleta falha declarando ─────────────────────
# Default silencioso aqui devolveria o literal em script pela porta dos fundos.

POLITICAS="$TMP/sem-politica"
saida="$(rodar "$BIN_OK" "${CREDENCIAIS[@]}")"
status=$?
afirmar_igual '1' "$status" 'política ausente faz sair != 0, em vez de assumir um número'
afirmar_contem 'política ausente' "$saida" 'e a mensagem diz que é a política que falta'

POLITICAS="$FIX/politica-sem-chave"
saida="$(rodar "$BIN_OK" "${CREDENCIAIS[@]}")"
status=$?
afirmar_igual '1' "$status" 'política sem a chave também faz sair != 0'
afirmar_contem 'tempo_limite_segundos' "$saida" 'e diz qual chave falta'

POLITICAS="$FIX/politica"

# ─── 6. Ferramenta ausente falha, não pula ──────────────────────────────────
# Mesma regra do shellcheck na suíte: verificação que se pula em silêncio é
# verificação que não existe.

saida="$(env -i PATH="$SO_BASH" SCULLY_SEM_ENV=1 SCULLY_POLITICAS_DIR="$POLITICAS" \
  bash "$SCRIPT" 2>&1)"
status=$?
afirmar_igual '1' "$status" 'curl ausente faz sair != 0'
afirmar_contem 'curl não está instalado' "$saida" 'e diz que nada foi verificado'

# ─── 7. A ajuda ─────────────────────────────────────────────────────────────

saida="$(env -i PATH="$BIN_OK:/usr/bin:/bin" SCULLY_SEM_ENV=1 \
  SCULLY_POLITICAS_DIR="$POLITICAS" bash "$SCRIPT" --ajuda 2>&1)"
status=$?
afirmar_igual '0' "$status" '--ajuda sai 0'
afirmar_contem 'Uso:' "$saida" 'e explica como se usa'
