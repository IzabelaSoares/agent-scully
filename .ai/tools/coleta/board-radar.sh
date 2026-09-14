#!/usr/bin/env bash
#
# Radar de prazo do board — devolve JSON pequeno e normalizado (TASKS C2).
#
# Responde uma pergunta só: **que bug está com o prazo estourado, e qual está
# para estourar?** Tudo o que decide a resposta — qual campo de prazo vale, em
# que precedência, o que vale sem nenhum preenchido, e os cortes do 🔴 e do 🟡 —
# sai de `.ai/politicas/prazo.yaml`. Nada disso é literal aqui, e
# `tests/casos/07-prazo.sh` falha no dia em que virar (decisões 0003).
#
# ⚠️ **Leitura, sempre.** A única chamada de rede é um `GET`, e a garantia é por
# capacidade: não há neste arquivo caminho que escreva no board (SPEC §6).
#
# ─── O que sai, e por que só isso ───────────────────────────────────────────
#
# {
#   "referencia":   "2026-09-14",   a data em que o radar julgou — sem ela nada
#                                   do resto é conferível, nem reproduzível
#   "total":        7,              o que o board diz existir, não o tamanho da
#                                   amostra: reportar `length` como total
#                                   subnotifica em silêncio (SPEC §10)
#   "examinados":   7,              o que de fato coube na amostra
#   "truncado":     false,          os dois acima divergem? então o laudo tem de
#                                   dizer que olhou só um pedaço
#   "sob_controle": 2,              quantos 🟢. É o número que deixa o laudo
#                                   AFIRMAR "prazos sob controle" em vez de
#                                   deixar a seção vazia (SPEC §7)
#   "itens": [ ... ]                só 🔴 e 🟡 — o que pede linha no laudo
#  }
#
# E cada item, com os campos que o julgamento usa e nenhum a mais:
#
#   chave            o identificador, e nada de conteúdo de ticket (SPEC §9)
#   base             "prazo" ou "idade" — de onde saiu o número
#   prazo_efetivo    a data que valeu             ] null quando a base é idade
#   campo_do_prazo   o campo de onde ela saiu     ]
#   dias_de_atraso   positivo = venceu; negativo = ainda vai vencer (base prazo)
#   dias_de_idade    dias desde a criação (base idade)
#   classificacao    🔴 / 🟡
#
# ⚠️ `dias_de_atraso` e `dias_de_idade` são campos **separados**, e não um só
# campo "dias" com dois significados. É a regra da política escrita na forma do
# dado: idade é estimativa desta casa e prazo é promessa, e um laudo que
# apresenta a primeira como a segunda perde crédito de uma vez. Com um campo só,
# a confusão fica a um descuido de distância; com dois, ela não tem como
# acontecer.
#
# ─── Uso ────────────────────────────────────────────────────────────────────
#
#   .ai/tools/coleta/board-radar.sh                      consulta o board
#   .ai/tools/coleta/board-radar.sh --amostra <arquivo>  lê resposta salva
#
# `--amostra` não é atalho de teste: é o que torna o número **conferível à mão**
# sobre a mesma entrada, que é o que a task C3 exige e o que um coletor que só
# fala com a rede não permite.
#
# `SCULLY_AGORA` congela a data de referência. Sem ela o radar usa o relógio — e
# aí a classificação é intestável, porque o mesmo comando muda de resposta
# amanhã.
#
# Status: 0 com o JSON no stdout; 1 com o motivo no stderr e **nada** no stdout.
# Saída pela metade é pior que saída nenhuma: ela parece resposta.
#
# ⚠️ **O que esta suíte NÃO prova:** o caminho de rede. O board do alvo nasce na
# Etapa 5 e não existe ainda, então a consulta abaixo está escrita e **não foi
# exercitada contra board nenhum**. O que a suíte prova é a normalização e a
# classificação, sobre amostra. Retentativa e o estado de fonte caída são a task
# C4, e até lá falha de coleta aqui é status ≠ 0 — nunca lista vazia.

set -uo pipefail

if [[ "${BASH_SOURCE[0]}" == */* ]]; then
  RAIZ="${BASH_SOURCE[0]%/*}/../../.."
else
  RAIZ="../../.."
fi
RAIZ="$(cd "$RAIZ" && pwd)" || exit 1

AMOSTRA=''
case "${1:-}" in
  --ajuda | -h)
    printf 'Uso: .ai/tools/coleta/board-radar.sh [--amostra <arquivo>]\n\n'
    printf 'Devolve JSON normalizado com o bug de prazo estourado (🔴) e o de\n'
    printf 'prazo a estourar na janela (🟡), mais a contagem do que está sob\n'
    printf 'controle. A precedência de campo e os cortes saem da política em\n'
    printf '.ai/politicas/prazo.yaml — nada disso é literal no script.\n\n'
    printf 'SCULLY_AGORA congela a data de referência.\n'
    exit 0
    ;;
  --amostra)
    AMOSTRA="${2:-}"
    if [ -z "$AMOSTRA" ]; then
      printf 'board-radar: --amostra exige um arquivo\n' >&2
      exit 1
    fi
    ;;
  '') ;;
  *)
    printf 'board-radar: argumento desconhecido; veja --ajuda\n' >&2
    exit 1
    ;;
esac

# ─── Ferramentas ────────────────────────────────────────────────────────────
# Ausente é falha declarada, nunca verificação que se pula em silêncio — mesma
# regra do `shellcheck` na suíte (SPEC §10).

for ferramenta in jq python3; do
  if ! command -v "$ferramenta" >/dev/null 2>&1; then
    printf 'board-radar: %s não está instalado — nada foi coletado\n' "$ferramenta" >&2
    exit 1
  fi
done

# ─── A política ─────────────────────────────────────────────────────────────
# Lida pelo leitor de `.ai/tools/lib/politica.py`, que é o mesmo que a suíte usa
# para verificá-la. Dois leitores deixariam a verificação passar sobre um
# arquivo que este script lê de outro jeito.

POLITICAS="${SCULLY_POLITICAS_DIR:-$RAIZ/.ai/politicas}"
ARQUIVO_POLITICA="$POLITICAS/prazo.yaml"

if [ ! -f "$ARQUIVO_POLITICA" ]; then
  printf 'board-radar: política ausente em %s\n' "$ARQUIVO_POLITICA" >&2
  printf '  Sem ela não há precedência de campo nem corte de classificação, e\n' >&2
  printf '  chutar aqui devolveria à mão o literal que a SPEC §9.1 tira.\n' >&2
  exit 1
fi

POLITICA=''
if ! POLITICA="$(python3 "$RAIZ/.ai/tools/lib/politica.py" "$ARQUIVO_POLITICA")"; then
  printf 'board-radar: política ilegível — nada foi coletado\n' >&2
  exit 1
fi

# Limiar que falta é limiar que voltaria como default silencioso aqui dentro.
for chave in janela_amarelo_dias idade_amarelo_dias; do
  valor="$(printf '%s' "$POLITICA" | jq -r --arg c "$chave" '.classificacao[$c] // ""')"
  if [[ ! "$valor" =~ ^[0-9]+$ ]]; then
    printf 'board-radar: %s não define classificacao.%s\n' "$ARQUIVO_POLITICA" "$chave" >&2
    exit 1
  fi
done

# ─── A data de referência ───────────────────────────────────────────────────
# Dia inteiro, e não instante: os campos de prazo do board são datas, e o
# numérico que o board deriva delas é justamente o que a política manda não usar
# para decidir — ele é recalculado na cadência do board e diverge por horas.

REFERENCIA="${SCULLY_AGORA:-$(date -u +%Y-%m-%d)}"
REFERENCIA="${REFERENCIA:0:10}"
if [[ ! "$REFERENCIA" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  printf 'board-radar: a data de referência não é AAAA-MM-DD — nada foi coletado\n' >&2
  printf '  Ou SCULLY_AGORA está malformada, ou `date` não respondeu. Classificar\n' >&2
  printf '  sem saber que dia é hoje daria número plausível, que é o pior número.\n' >&2
  exit 1
fi

# ─── A carga: da amostra, ou do board ───────────────────────────────────────

if [ -n "$AMOSTRA" ]; then
  if [ ! -f "$AMOSTRA" ]; then
    printf 'board-radar: amostra ausente: %s\n' "$AMOSTRA" >&2
    exit 1
  fi
  # Leitura por redireção, e não por `cat`: um comando externo a menos é um
  # modo a menos de este script sair 0 com a saída vazia quando o ambiente está
  # pelado. A suíte pegou exatamente isso rodando com um PATH sem `cat`.
  CARGA="$(<"$AMOSTRA")"
else
  # O ambiente ganha do arquivo (SPEC §10) — é o que torna testável o caminho
  # de "a credencial não serve". Linha malformada já se anunciou pelo número no
  # stderr da própria biblioteca; as boas foram carregadas, e o que importa para
  # esta consulta é conferido logo abaixo.
  # shellcheck source=/dev/null
  . "$RAIZ/.ai/tools/lib/env.sh"
  ambiente_carregar "$RAIZ/.env" || true

  faltando=()
  for nome in BOARD_BASE_URL BOARD_EMAIL BOARD_API_TOKEN BOARD_PROJETO; do
    [ -n "${!nome:-}" ] || faltando+=("$nome")
  done
  if [ "${#faltando[@]}" -gt 0 ]; then
    printf 'board-radar: sem credencial do board — falta %s\n' "${faltando[*]}" >&2
    printf '  Nada foi coletado. Fonte não configurada NÃO é fila vazia, e\n' >&2
    printf '  transformá-la em `[]` é a falha silenciosa que a SPEC §1 proíbe.\n' >&2
    printf '  (O estado `nao_integrada` na própria saída é a task C4.)\n' >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    printf 'board-radar: curl não está instalado — nada foi coletado\n' >&2
    exit 1
  fi

  # A credencial vai por arquivo de configuração no STDIN, nunca por argumento:
  # argumento de processo é legível por qualquer `ps` da máquina. Mesmo cuidado,
  # e mesma razão, de ops/verificar-credenciais.sh.
  escapar() {
    local valor="${1//\\/\\\\}"
    printf '%s' "${valor//\"/\\\"}"
  }

  # Quebra de linha viraria OUTRA opção do arquivo de configuração — inclusive
  # outra `url`, o que mandaria a credencial para outro host.
  case "$BOARD_BASE_URL$BOARD_EMAIL$BOARD_API_TOKEN$BOARD_PROJETO" in
    *$'\n'*)
      printf 'board-radar: valor de ambiente com quebra de linha — recusado sem chamar\n' >&2
      exit 1
      ;;
  esac

  # `get` é explícito: a capacidade deste coletor é ler, e está dita na chamada.
  # `*navigable` traz os campos com nome resolvido em `names`, que é o que
  # permite casar política → campo sem id numérico neste repositório — id de
  # campo customizado identifica a instância de quem o tem (decisões 0002).
  config="url = \"$(escapar "${BOARD_BASE_URL%/}")/rest/api/3/search/jql\""
  config="$config"$'\n'"user = \"$(escapar "$BOARD_EMAIL:$BOARD_API_TOKEN")\""
  config="$config"$'\n'"get"
  config="$config"$'\n'"data-urlencode = \"jql=project = $(escapar "$BOARD_PROJETO") AND statusCategory != Done ORDER BY created ASC\""
  config="$config"$'\n'"data-urlencode = \"fields=*navigable\""
  config="$config"$'\n'"data-urlencode = \"expand=names\""

  CARGA="$(printf '%s\n' "$config" | curl --config - --silent --show-error 2>/dev/null)"
  status=$?
  if [ "$status" -ne 0 ] || [ -z "$CARGA" ]; then
    # Motivo em texto fixo, escolhido aqui: mensagem de rede cita o host, e o
    # host identifica a instância de quem clonou.
    printf 'board-radar: a consulta ao board não voltou (curl saiu %s) — nada foi coletado\n' \
      "$status" >&2
    exit 1
  fi
fi

# ─── Normalização e classificação ───────────────────────────────────────────
# Tudo o que decide sai de `$p`. O que este programa sabe é **aplicar** a
# política, não escolher campo.

PROGRAMA='
# Valor de campo como o board o devolve: texto, ou objeto de campo de seleção.
# Vazio é indistinguível de ausente para efeito de precedência.
def texto($v):
  if $v == null then null
  elif ($v | type) == "string" then (if ($v | gsub("^\\s+|\\s+$"; "")) == "" then null else $v end)
  elif ($v | type) == "object" then (if ($v.value | type) == "string" then $v.value else null end)
  else null end;

# Dia inteiro em UTC. Data ilegível NÃO vira null: null a mandaria para o
# fallback, e um prazo de verdade seria reportado como idade — que é o erro
# que a política existe para impedir. Vira problema, e problema para o radar.
def dia($s):
  if $s == null then null
  else (try (($s[0:10] | strptime("%Y-%m-%d") | mktime) / 86400 | floor) catch "ilegivel")
  end;

def valor($issue; $nome; $id_de):
  ($id_de[$nome] // null) as $id
  | if $id == null then null else texto($issue.fields[$id]) end;

. as $carga
| ($carga.names // {} | to_entries | map({key: .value, value: .key}) | from_entries) as $id_de
| ($p.classificacao.janela_amarelo_dias | tonumber) as $janela
| ($p.classificacao.idade_amarelo_dias | tonumber) as $corte_idade
| ($ref | strptime("%Y-%m-%d") | mktime / 86400 | floor) as $hoje
| [ $carga.issues[]? ] as $issues
| [
    $issues[]
    | . as $issue
    | (valor($issue; $p.origem.campo; $id_de)) as $rotulo
    | ((if $rotulo == null then null else $p.origem.valores[$rotulo] end) // $p.origem.padrao) as $origem
    | ($p.origens[$origem].campos // []) as $campos
    | ([ $campos[] | select(valor($issue; .; $id_de) != null) ] | first) as $campo
    | (if $campo == null then null else valor($issue; $campo; $id_de) end) as $prazo
    | (dia($prazo)) as $d_prazo
    | (dia($issue.fields.created)) as $d_criacao
    | if $d_prazo == "ilegivel" then
        {problema: "\($issue.key): data ilegível no campo de prazo que a política escolheu"}
      elif $d_criacao == "ilegivel" or ($campo == null and $d_criacao == null) then
        {problema: "\($issue.key): sem prazo declarado e sem data de criação legível"}
      elif $campo != null then
        ($hoje - $d_prazo) as $atraso
        | {
            chave: $issue.key,
            base: "prazo",
            prazo_efetivo: $prazo[0:10],
            campo_do_prazo: $campo,
            dias_de_atraso: $atraso,
            dias_de_idade: null,
            classificacao: (if $atraso > 0 then "🔴"
                            elif (-$atraso) <= $janela then "🟡"
                            else "🟢" end),
            ordem: $atraso
          }
      else
        ($hoje - $d_criacao) as $idade
        | {
            chave: $issue.key,
            base: "idade",
            prazo_efetivo: null,
            campo_do_prazo: null,
            dias_de_atraso: null,
            dias_de_idade: $idade,
            # Nunca 🔴: idade é estimativa desta casa, não promessa a estourar.
            classificacao: (if $idade >= $corte_idade then "🟡" else "🟢" end),
            ordem: $idade
          }
      end
  ] as $julgados
| [ $julgados[] | select(has("problema")) | .problema ] as $problemas
| [ $julgados[] | select(has("problema") | not) ] as $itens
| ($carga.total // null) as $declarado
| {
    problemas: $problemas,
    saida: {
      referencia: $ref,
      total: ($declarado // ($issues | length)),
      examinados: ($issues | length),
      truncado: (
        ($declarado != null and $declarado > ($issues | length))
        or ($carga.isLast == false)
        or ($carga.nextPageToken != null)
      ),
      sob_controle: ([ $itens[] | select(.classificacao == "🟢") ] | length),
      itens: (
        [ $itens[] | select(.classificacao != "🟢") ]
        # 🔴 antes de 🟡; dentro da classe, quem espera há mais tempo primeiro.
        | sort_by([(if .classificacao == "🔴" then 0 else 1 end), -.ordem, .chave])
        | map(del(.ordem))
      )
    }
  }
'

if [ -z "${CARGA//[[:space:]]/}" ]; then
  printf 'board-radar: a carga do board veio vazia — nada foi coletado\n' >&2
  exit 1
fi

# ⚠️ Duas conferências, e não uma: `jq` sai **0** sobre entrada vazia, e sem
# imprimir nada. Conferir só o status deixaria este script sair 0 com a saída
# vazia — a falha silenciosa que a SPEC §1 proíbe, e que a suíte pegou aqui
# rodando num ambiente sem as ferramentas de sempre.
#
# O stderr do `jq` não é repassado: ele ecoa a entrada, e a entrada é resposta
# de board — assunto de ticket entra nela, e assunto traz nome de pessoa.
JULGADO=''
if ! JULGADO="$(printf '%s' "$CARGA" |
  jq --argjson p "$POLITICA" --arg ref "$REFERENCIA" "$PROGRAMA" 2>/dev/null)" ||
  [ -z "$JULGADO" ]; then
  printf 'board-radar: a resposta do board não é o JSON esperado — nada foi coletado\n' >&2
  exit 1
fi

mapfile -t PROBLEMAS < <(printf '%s' "$JULGADO" | jq -r '.problemas[]')
if [ "${#PROBLEMAS[@]}" -gt 0 ]; then
  printf 'board-radar: %s issue(s) que o radar não sabe julgar — nada foi coletado\n' \
    "${#PROBLEMAS[@]}" >&2
  printf '  %s\n' "${PROBLEMAS[@]}" >&2
  printf '  Julgar o que não se entende é a saída plausível que a SPEC §1 proíbe.\n' >&2
  exit 1
fi

printf '%s' "$JULGADO" | jq '.saida'
