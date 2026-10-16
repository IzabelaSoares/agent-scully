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
#   "indisponivel": false,          a fonte falhou NESTA execução, depois das
#                                   retentativas — exige atenção
#   "nao_integrada":false,          a fonte não está configurada — lacuna
#                                   conhecida, e não problema do dia
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
# ⚠️ Nos dois estados de falha a saída tem **só** as três primeiras chaves: sem
# `total`, sem `examinados`, sem `sob_controle` e **sem `itens`** (TASKS C4).
# A ausência é deliberada e é a regra na forma do dado — `itens: []` se lê como
# "não havia nada" e `total: 0` como "a fila está vazia", que é precisamente o
# que a SPEC §1 proíbe. Quem consome lê `null` ao pedir `.itens`, e `null` não
# se confunde com lista vazia. Os dois estados são distinguíveis entre si
# porque são duas chaves, e não dois valores de uma: fonte caída exige atenção
# hoje; fonte não integrada é lacuna planejada, e um ⚠️ que aparece todo dia
# por semanas treina o time a ignorá-lo (SPEC §7).
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
# Status: 0 com o JSON no stdout — **inclusive** nos dois estados de falha
# acima, porque reportar a falha é ter conseguido responder, e é o que permite
# ao laudo sair com a seção marcada em vez de omitir em silêncio (SPEC §7). O
# que sai 1, com o motivo no stderr e **nada** no stdout, é o que este coletor
# não sabe reportar: política ausente, ferramenta ausente, resposta que ele não
# entende. Saída pela metade é pior que saída nenhuma: ela parece resposta.
#
# Todo diagnóstico — código HTTP, número da tentativa — vai para o **stderr**.
# Ele é log da execução, e não conteúdo de laudo (SPEC §7).
#
# ⚠️ **O que esta suíte NÃO prova:** que a consulta funcione contra um board de
# verdade. O board do alvo nasce na Etapa 5 e não existe ainda, então o JQL e os
# campos abaixo **não foram exercitados contra board nenhum**. O que a suíte
# prova é a normalização, a classificação e — com dublê de `curl`, em
# `tests/casos/10-radar-indisponivel.sh` — a retentativa e os dois estados de
# falha.

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

# ─── Os dois estados declarados de falha ────────────────────────────────────
# A SPEC §7 distingue fonte CAÍDA de fonte NÃO INTEGRADA, e proíbe que qualquer
# uma vire número. Aqui isso é estrutura: a saída de estado não tem `total`,
# não tem `sob_controle` e **não tem `itens`** — não há lista vazia a confundir
# com fila vazia, porque não há lista.

estado() {
  jq -n --arg ref "$REFERENCIA" --arg qual "$1" '{
    referencia: $ref,
    indisponivel: ($qual == "indisponivel"),
    nao_integrada: ($qual == "nao_integrada")
  }'
}

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
    # Fonte não configurada é LACUNA, não incidente: ela sai como estado na
    # própria saída, para o laudo marcá-la 🚧 em vez de omitir a seção. Nada
    # foi coletado, e nada vira `[]` — fila vazia é outra afirmação.
    printf 'board-radar: sem credencial do board — falta %s\n' "${faltando[*]}" >&2
    printf '  Nada foi coletado; a saída sai marcada como não integrada.\n' >&2
    estado nao_integrada
    exit 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    printf 'board-radar: curl não está instalado — nada foi coletado\n' >&2
    exit 1
  fi

  # ─── A política de coleta ────────────────────────────────────────────────
  # Quantas tentativas e quanto se espera saem de `coleta.yaml` (TASKS C4). O
  # que conta como erro **transitório** não sai de lá: 5xx, 429 e timeout são
  # contrato da SPEC §7, e não limiar que se ajusta sem decisão (SPEC §9.1).
  #
  # Lida só AQUI, e não junto com a de prazo: com `--amostra` não há chamada a
  # repetir, e exigi-la ali obrigaria todo dublê de política da suíte a trazer
  # um arquivo que o caminho exercitado não usa.

  ARQUIVO_COLETA="$POLITICAS/coleta.yaml"
  if [ ! -f "$ARQUIVO_COLETA" ]; then
    printf 'board-radar: política de coleta ausente em %s\n' "$ARQUIVO_COLETA" >&2
    printf '  Sem ela não há quantas tentativas nem quanto esperar, e assumir\n' >&2
    printf '  um número aqui devolveria à mão o literal que a SPEC §9.1 tira.\n' >&2
    exit 1
  fi

  COLETA=''
  if ! COLETA="$(python3 "$RAIZ/.ai/tools/lib/politica.py" "$ARQUIVO_COLETA")"; then
    printf 'board-radar: política de coleta ilegível — nada foi coletado\n' >&2
    exit 1
  fi

  # Limiar que falta é limiar que voltaria como default silencioso aqui dentro.
  #
  # Declaradas uma por linha, e não quatro numa só: variável que nasce apenas
  # de um `printf -v` fica invisível para quem varre o script atrás do que ele
  # lê, e aparece como variável de ambiente não documentada (TASKS B2). Foi o
  # `tests/casos/04-inventario.sh` que pegou, com as quatro numa linha.
  TENTATIVAS_EXTRAS=''
  ESPERA_INICIAL=''
  FATOR_DE_ESPERA=''
  TEMPO_LIMITE=''
  for par in \
    'TENTATIVAS_EXTRAS .retentativa.tentativas_extras' \
    'ESPERA_INICIAL .retentativa.espera_inicial_segundos' \
    'FATOR_DE_ESPERA .retentativa.fator_de_espera' \
    'TEMPO_LIMITE .tempo_limite_segundos'; do
    nome="${par%% *}"
    caminho="${par#* }"
    valor="$(printf '%s' "$COLETA" | jq -r "$caminho // \"\"")"
    if [[ ! "$valor" =~ ^[0-9]+$ ]]; then
      printf 'board-radar: %s não define %s\n' "$ARQUIVO_COLETA" "${caminho#.}" >&2
      exit 1
    fi
    printf -v "$nome" '%s' "$valor"
  done

  # Fator menor que 1 faria a espera ENCOLHER a cada tentativa, que é o oposto
  # do que a SPEC §7 pede — e passaria despercebido, porque continua esperando.
  if [ "$FATOR_DE_ESPERA" -lt 1 ]; then
    printf 'board-radar: %s define fator_de_espera < 1 — a espera encolheria\n' \
      "$ARQUIVO_COLETA" >&2
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

  # ─── A chamada, e as retentativas ────────────────────────────────────────
  # `--write-out` acrescenta o código HTTP numa linha depois do corpo. Sem ele
  # o `curl` sai **0** numa resposta 500, e um 500 indistinguível de um 200 é
  # um erro transitório que nunca seria repetido — e um corpo de erro entregue
  # ao `jq` como se fosse board (SPEC §10).
  #
  # O motivo que se imprime é escolhido aqui, nunca o que a rede devolveu:
  # mensagem de `curl` cita o host, e o host identifica a instância de quem
  # clonou (decisões 0002). E vai para o stderr, que é log da execução: código
  # HTTP não entra em saída que o laudo lê (SPEC §7).

  CARGA=''
  tentativa=1
  espera="$ESPERA_INICIAL"
  total_tentativas=$((TENTATIVAS_EXTRAS + 1))

  while :; do
    resposta="$(printf '%s\n' "$config" | curl --config - \
      --silent --show-error --write-out '\n%{http_code}' \
      --max-time "$TEMPO_LIMITE" 2>/dev/null)"
    status=$?
    codigo="${resposta##*$'\n'}"
    corpo="${resposta%$'\n'*}"
    # Resposta que não se entende não é resposta que se repassa.
    [[ "$codigo" =~ ^[0-9]{3}$ ]] || codigo='000'

    if [ "$status" -eq 0 ] && [[ "$codigo" =~ ^2[0-9][0-9]$ ]]; then
      CARGA="$corpo"
      break
    fi

    # Transitório é o que a SPEC §7 enumera, e só: 5xx, 429 e timeout. Repetir
    # um 401 é gastar a janela da ronda num erro que não muda sozinho.
    transitorio=0
    if [ "$status" -eq 28 ]; then
      transitorio=1
      motivo='estourou o tempo-limite'
    elif [ "$status" -ne 0 ]; then
      motivo="curl saiu $status"
    else
      motivo="HTTP $codigo"
      if [ "$codigo" = '429' ] || [[ "$codigo" =~ ^5[0-9][0-9]$ ]]; then
        transitorio=1
      fi
    fi

    if [ "$transitorio" -eq 1 ] && [ "$tentativa" -lt "$total_tentativas" ]; then
      printf 'board-radar: tentativa %s de %s falhou (%s) — nova tentativa em %ss\n' \
        "$tentativa" "$total_tentativas" "$motivo" "$espera" >&2
      [ "$espera" -gt 0 ] && sleep "$espera"
      espera=$((espera * FATOR_DE_ESPERA))
      tentativa=$((tentativa + 1))
      continue
    fi

    printf 'board-radar: o board não respondeu (%s) em %s tentativa(s) — nada foi coletado\n' \
      "$motivo" "$tentativa" >&2
    printf '  A saída sai marcada como indisponível. Fonte caída NÃO é fila\n' >&2
    printf '  vazia, e virar `[]` é a falha silenciosa que a SPEC §1 proíbe.\n' >&2
    estado indisponivel
    exit 0
  done
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
      # Declarados também aqui, e sempre: "a fonte respondeu" é afirmação, e
      # afirmação não se infere da ausência de uma chave (SPEC §1).
      indisponivel: false,
      nao_integrada: false,
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
