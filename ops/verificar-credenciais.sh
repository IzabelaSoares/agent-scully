#!/usr/bin/env bash
#
# Confere cada credencial do `.env` com a chamada mais barata de cada API e
# reporta ✅ / ❌ / 🚧 — nunca o valor, nem em caso de erro (TASKS B3).
#
# Três estados, e nenhum vira o outro (SPEC §9 e §11):
#
#   ✅ verificada  a chamada mínima respondeu 2xx com esta credencial
#   ❌ falhou      a credencial está preenchida e a chamada não passou, com o motivo
#   🚧 lacuna      não configurada, ou fonte ainda não integrada
#
# Status de saída: 0 nada a apontar; 1 alguma falha; 2 sem falha, com lacuna.
# São três porque "não configurada" **não** é "recusada" — confundir as duas é
# exatamente o que a SPEC §11 proíbe, e é o diagnóstico mais caro de todos:
# credencial ausente que se lê como credencial inválida manda quem está de
# plantão rotacionar um token que estava bom.
#
# ⚠️ Como esta saída fica livre de segredo — três camadas, porque uma só é
# esquecida no primeiro `printf` de depuração que alguém acrescentar:
#
#   1. **Capacidade.** O segredo vai ao `curl` por arquivo de configuração no
#      STDIN, **nunca por argumento**: argumento de processo é legível por
#      qualquer usuário da máquina em `ps`.
#   2. **O que se imprime é escolhido, não repassado.** A saída do `curl` é
#      recusada quando não é um código HTTP de três dígitos, e o stderr dele é
#      descartado inteiro: mensagem de erro de rede cita o host, e o host
#      identifica a instância de quem clonou.
#   3. **Censura na única porta de saída.** Todo texto impresso passa por
#      `censurar`, que troca por «omitido» qualquer valor de credencial — ou de
#      URL de base — presente no ambiente.
#
# A terceira sozinha não bastaria (só pega o que já conhece) e a primeira
# sozinha também não (não cobre o que a resposta traz de volta). É o mesmo
# raciocínio de camadas da SPEC §6: cada uma na força que suporta.
#
# Uso:
#   ops/verificar-credenciais.sh
#   SCULLY_SEM_ENV=1 ops/verificar-credenciais.sh   # ignora o .env por completo

set -uo pipefail

if [[ "${BASH_SOURCE[0]}" == */* ]]; then
  RAIZ="${BASH_SOURCE[0]%/*}/.."
else
  RAIZ=".."
fi
RAIZ="$(cd "$RAIZ" && pwd)" || exit 1

if [ ! -f "$RAIZ/.ai/tools/lib/env.sh" ]; then
  printf 'verificar-credenciais: biblioteca de ambiente ausente — nada foi verificado\n' >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$RAIZ/.ai/tools/lib/env.sh"

if [ "${1:-}" = "--ajuda" ] || [ "${1:-}" = "-h" ]; then
  printf 'Uso: ops/verificar-credenciais.sh\n\n'
  printf 'Confere cada credencial do .env com uma chamada mínima e reporta\n'
  printf '✅ verificada, ❌ falhou (com o motivo) ou 🚧 lacuna — nunca o valor.\n'
  printf 'Sai 0 sem nada a apontar, 1 com falha, 2 com lacuna e sem falha.\n'
  exit 0
fi

# ─── Política: o limiar é dado, não literal ─────────────────────────────────

POLITICAS="${SCULLY_POLITICAS_DIR:-$RAIZ/.ai/politicas}"
ARQUIVO_POLITICA="$POLITICAS/verificacao.yaml"

# Lê `chave: número` do arquivo de política. Bash puro de propósito: o único
# comando externo deste script é o `curl`, e é isso que permite ao caso da
# suíte provar que ele reclama quando o `curl` falta.
politica_numero() {
  local chave="$1" linha
  while IFS= read -r linha || [ -n "$linha" ]; do
    [[ "$linha" =~ ^[[:space:]]*${chave}:[[:space:]]*([0-9]+) ]] || continue
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  done <"$ARQUIVO_POLITICA"
  return 1
}

if [ ! -f "$ARQUIVO_POLITICA" ]; then
  printf 'verificar-credenciais: política ausente em %s\n' "$ARQUIVO_POLITICA" >&2
  printf '  Sem ela não há tempo-limite, e chutar um número aqui devolveria à\n' >&2
  printf '  mão o literal em script que a SPEC §9.1 tira.\n' >&2
  exit 1
fi

TEMPO_LIMITE="$(politica_numero tempo_limite_segundos)"
if [ -z "$TEMPO_LIMITE" ]; then
  printf 'verificar-credenciais: %s não define tempo_limite_segundos\n' \
    "$ARQUIVO_POLITICA" >&2
  exit 1
fi

# Falta de `curl` é falha declarada, não verificação que se pula em silêncio —
# mesma razão do `shellcheck` ausente falhar a suíte (SPEC §10).
if ! command -v curl >/dev/null 2>&1; then
  printf 'verificar-credenciais: curl não está instalado — nada foi verificado\n' >&2
  exit 1
fi

# ─── O que nunca pode aparecer na saída ─────────────────────────────────────

# Credencial e também URL de base: o subdomínio de uma instância de SaaS
# identifica a organização, e log de CI é público (decisões 0002).
SEGREDOS=()

registrar_valor() {
  local nome
  for nome in "$@"; do
    [ -n "${!nome:-}" ] && SEGREDOS+=("${!nome}")
  done
  return 0
}

censurar() {
  local texto="$1" valor
  for valor in "${SEGREDOS[@]:-}"; do
    # Valor curto demais casaria com meio mundo e transformaria a saída em
    # picadinho; credencial de verdade não tem três caracteres.
    [ "${#valor}" -ge 4 ] || continue
    texto="${texto//"$valor"/«omitido»}"
  done
  printf '%s' "$texto"
}

# ─── Relato ─────────────────────────────────────────────────────────────────

verificadas=0
falhas=0
lacunas=0

# Porta de saída única: nada é impresso sem passar por aqui, e aqui tudo passa
# pela censura.
relatar() {
  printf '%s %-12s %s\n' "$1" "$2" "$(censurar "$3")"
}

verificada() {
  verificadas=$((verificadas + 1))
  relatar '✅' "$1" "$2"
}

falhou() {
  falhas=$((falhas + 1))
  relatar '❌' "$1" "$2"
}

lacuna() {
  lacunas=$((lacunas + 1))
  relatar '🚧' "$1" "$2"
}

# ─── A chamada ──────────────────────────────────────────────────────────────

# No arquivo de configuração do curl, `\` e `"` dentro de um valor entre aspas
# são escapados com barra invertida. Token com aspas é raro e legal — e sem isto
# ele fecharia a aspa e o curl reportaria um erro que não é o erro que existe.
escapar() {
  local valor="${1//\\/\\\\}"
  printf '%s' "${valor//\"/\\\"}"
}

# Devolve "<código http> <status do curl>", e nada mais: o corpo da resposta vai
# para /dev/null e o stderr do curl é descartado. Código que não seja três
# dígitos vira 000 — resposta que não se entende não é resposta que se repassa.
consultar() {
  local url="$1" credencial="${2:-}" cabecalho="${3:-}"
  local config codigo status

  # Quebra de linha num valor viraria OUTRA opção do arquivo de configuração —
  # inclusive outra `url`, o que mandaria a credencial para outro lugar. Recusar
  # antes de chamar é mais barato, e mais confiável, que tentar sanear.
  case "$url$credencial$cabecalho" in
    *$'\n'*)
      printf '%s %s' '000' '901'
      return
      ;;
  esac

  config="url = \"$(escapar "$url")\""
  [ -n "$credencial" ] && config="$config"$'\n'"user = \"$(escapar "$credencial")\""
  [ -n "$cabecalho" ] && config="$config"$'\n'"header = \"$(escapar "$cabecalho")\""

  # `--config -` lê as opções do STDIN. É o que mantém a credencial fora do
  # argumento de processo, onde qualquer `ps` a leria.
  codigo="$(printf '%s\n' "$config" | curl --config - \
    --silent --output /dev/null \
    --write-out '%{http_code}' --max-time "$TEMPO_LIMITE" 2>/dev/null)"
  status=$?

  [[ "$codigo" =~ ^[0-9]{3}$ ]] || codigo='000'
  printf '%s %s' "$codigo" "$status"
}

# Motivo em texto fixo, escolhido aqui — jamais o que a rede devolveu.
motivo_de() {
  local codigo="$1" status="$2"

  if [ "$status" -ne 0 ]; then
    case "$status" in
      # 901 não é status de curl: é a recusa desta casa, antes de chamar.
      901) printf 'valor com quebra de linha — recusado sem chamar' ;;
      6) printf 'não resolveu o host' ;;
      7) printf 'não conectou ao host' ;;
      28) printf 'estourou o tempo-limite de %ss' "$TEMPO_LIMITE" ;;
      35 | 60) printf 'erro de TLS' ;;
      *) printf 'curl saiu %s' "$status" ;;
    esac
    return
  fi

  case "$codigo" in
    000) printf 'resposta ilegível (não veio código HTTP)' ;;
    2??) printf 'HTTP %s' "$codigo" ;;
    401) printf 'HTTP 401 — credencial recusada' ;;
    403) printf 'HTTP 403 — credencial sem permissão para isto' ;;
    404) printf 'HTTP 404 — não encontrado; em token de escopo fino é assim que falta de escopo aparece' ;;
    429) printf 'HTTP 429 — limite de taxa' ;;
    *) printf 'HTTP %s' "$codigo" ;;
  esac
}

julgar() {
  local fonte="$1" leitura="$2" codigo status
  read -r codigo status <<<"$leitura"
  if [ "$status" -eq 0 ] && [[ "$codigo" =~ ^2[0-9][0-9]$ ]]; then
    verificada "$fonte" "$(motivo_de "$codigo" "$status")"
  else
    falhou "$fonte" "$(motivo_de "$codigo" "$status")"
  fi
}

# Nomes das variáveis vazias ou ausentes, em ordem.
faltando() {
  local nome
  local -a vazias=()
  for nome in "$@"; do
    [ -n "${!nome:-}" ] || vazias+=("$nome")
  done
  printf '%s' "${vazias[*]:-}"
}

# ─── Carrega o ambiente ─────────────────────────────────────────────────────

# O ambiente ganha do arquivo (SPEC §10). `TOKEN=invalido` nesta chamada
# exercita o caminho de falha, que é metade da razão desta verificação existir.
if ! ambiente_carregar "$RAIZ/.env"; then
  falhas=$((falhas + 1))
  relatar '❌' '.env' 'tem linha malformada — ver os números acima; as linhas boas foram carregadas'
fi

registrar_valor BOARD_BASE_URL BOARD_EMAIL BOARD_API_TOKEN SLACK_WEBHOOK_URL \
  APM_BASE_URL APM_API_TOKEN LANGFUSE_HOST LANGFUSE_PUBLIC_KEY \
  LANGFUSE_SECRET_KEY HELPDESK_BASE_URL HELPDESK_EMAIL HELPDESK_API_TOKEN \
  GH_TOKEN ALVO_REPO

ausentes=''

# ─── Board (Jira Cloud) ─────────────────────────────────────────────────────
# `myself` é a chamada mais barata que existe e responde exatamente a pergunta
# desta verificação: esta credencial autentica?
ausentes="$(faltando BOARD_BASE_URL BOARD_EMAIL BOARD_API_TOKEN)"
if [ -n "$ausentes" ]; then
  lacuna 'board' "não configurada — falta $ausentes"
else
  julgar 'board' \
    "$(consultar "${BOARD_BASE_URL%/}/rest/api/3/myself" "$BOARD_EMAIL:$BOARD_API_TOKEN")"
fi

# ─── Slack ──────────────────────────────────────────────────────────────────
# Webhook não tem chamada de leitura: conferir exige POST, e escrita é do
# wrapper da Etapa 3 (SPEC §5.2), não de um script de diagnóstico. Reportar
# ✅ por a variável estar preenchida seria dar por verificada uma credencial
# que ninguém exercitou — a saída plausível que a §1 proíbe.
ausentes="$(faltando SLACK_WEBHOOK_URL)"
if [ -n "$ausentes" ]; then
  lacuna 'slack' "não configurada — falta $ausentes"
else
  lacuna 'slack' 'preenchida, e não verificável sem postar: a checagem vive no wrapper da Etapa 3'
fi

# ─── APM ────────────────────────────────────────────────────────────────────
# Sem endpoint mínimo enquanto o fornecedor não está escolhido (Etapa 6).
ausentes="$(faltando APM_BASE_URL APM_API_TOKEN)"
if [ -n "$ausentes" ]; then
  lacuna 'apm' "não configurada — falta $ausentes"
else
  lacuna 'apm' 'preenchida, e a fonte não está integrada: o endpoint mínimo é escolhido na Etapa 6'
fi

# ─── Langfuse ───────────────────────────────────────────────────────────────
# A listagem de projetos é a menor chamada autenticada da API pública, e é
# leitura — o par de chaves vai como usuário e senha de basic auth.
ausentes="$(faltando LANGFUSE_HOST LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY)"
if [ -n "$ausentes" ]; then
  lacuna 'langfuse' "não configurada — falta $ausentes"
else
  julgar 'langfuse' \
    "$(consultar "${LANGFUSE_HOST%/}/api/public/projects" "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY")"
fi

# ─── Helpdesk ───────────────────────────────────────────────────────────────
# Mesma razão do APM: o sandbox é escolhido na Etapa 8.
ausentes="$(faltando HELPDESK_BASE_URL HELPDESK_EMAIL HELPDESK_API_TOKEN)"
if [ -n "$ausentes" ]; then
  lacuna 'helpdesk' "não configurada — falta $ausentes"
else
  lacuna 'helpdesk' 'preenchida, e a fonte não está integrada: o sandbox é escolhido na Etapa 8'
fi

# ─── GitHub ─────────────────────────────────────────────────────────────────
# Duas perguntas diferentes, e as duas doem: o token vale? e ele alcança o
# repositório do alvo? Token de escopo fino sem acesso responde 404, não 401 —
# está no `.env.example` porque é o erro que parece outra coisa.
ausentes="$(faltando GH_TOKEN)"
if [ -n "$ausentes" ]; then
  lacuna 'github' "não configurada — falta $ausentes"
else
  julgar 'github' \
    "$(consultar 'https://api.github.com/user' '' "Authorization: Bearer $GH_TOKEN")"

  ausentes="$(faltando ALVO_REPO)"
  if [ -n "$ausentes" ]; then
    lacuna 'github/alvo' "sem repositório do alvo — falta $ausentes"
  else
    julgar 'github/alvo' \
      "$(consultar "https://api.github.com/repos/$ALVO_REPO" '' "Authorization: Bearer $GH_TOKEN")"
  fi
fi

# ─── Fecho ──────────────────────────────────────────────────────────────────

printf '\n%s verificada(s), %s falha(s), %s lacuna(s) — tempo-limite: %ss (%s)\n' \
  "$verificadas" "$falhas" "$lacunas" "$TEMPO_LIMITE" \
  "${ARQUIVO_POLITICA#"$RAIZ"/}"

if [ "$falhas" -gt 0 ]; then
  exit 1
fi
if [ "$lacunas" -gt 0 ]; then
  exit 2
fi
# Estando tudo saudável, dizer isso explicitamente (SPEC §9).
printf 'Nada a apontar: toda credencial configurada respondeu.\n'
exit 0
