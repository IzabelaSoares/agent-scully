#!/usr/bin/env bash
#
# O `PRIMEIRO-DIA.md` continua dizendo a verdade (TASKS B4).
#
# Documento de primeiro contato apodrece de um jeito específico e caro: o
# repositório anda, o arquivo não, e quem chega segue um passo que não existe
# mais. Perde-se a pessoa exatamente no momento em que ela tinha menos contexto
# para desconfiar.
#
# As quatro verificações, e o que cada uma pega:
#
#   1. **Todo caminho citado existe.** Pega renomeação de script e de documento.
#   2. **Todo passo tem prova.** A promessa do arquivo é que cada passo termina
#      num comando cuja saída se confere; passo sem prova é afirmação.
#   3. **O código de saída prometido é o que o script devolve.** Pega a
#      divergência entre documentação e comportamento — a mesma rede que a
#      política de prazo vai exigir na Etapa 2.
#   4. **A declaração de que não há coletor cai quando houver coletor.** É uma
#      catraca: o dia em que o primeiro coletor entrar, este caso falha e obriga
#      o arquivo a ser atualizado junto.
#
# Roda sem credencial e sem rede: o único passo que faz chamada é exercitado
# aqui com um dublê de `curl`, em ambiente limpo.

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

DOC="$RAIZ/PRIMEIRO-DIA.md"

afirmar_arquivo "$DOC" "existe: PRIMEIRO-DIA.md"
if git ls-files --error-unmatch PRIMEIRO-DIA.md >/dev/null 2>&1; then
  afirmar 0 'PRIMEIRO-DIA.md está rastreado (a sanitização só varre rastreado)'
else
  afirmar 1 'PRIMEIRO-DIA.md está rastreado (a sanitização só varre rastreado)'
fi

# ─── 1. Todo caminho citado existe ──────────────────────────────────────────
# Só tokens com `/`: é o que distingue caminho de repositório de nome solto
# como `.env`, que não existe num clone recém-feito e não deve existir.

mapfile -t citados < <(
  grep -oE '[A-Za-z0-9_.][A-Za-z0-9_.-]*(/[A-Za-z0-9_.-]+)+' "$DOC" |
    grep -v '://' | sort -u
)

ausentes=()
for caminho in "${citados[@]}"; do
  [ -e "$RAIZ/$caminho" ] || ausentes+=("$caminho")
done

if [ "${#citados[@]}" -eq 0 ]; then
  # Zero caminho extraído passaria na asserção seguinte sem ter olhado nada.
  afirmar 1 'o documento cita caminho do repositório (a asserção seguinte não é vazia)'
else
  afirmar 0 "o documento cita ${#citados[@]} caminho(s) do repositório"
fi

if [ "${#ausentes[@]}" -eq 0 ]; then
  afirmar 0 'todo caminho citado no PRIMEIRO-DIA.md existe'
else
  afirmar 1 'todo caminho citado no PRIMEIRO-DIA.md existe'
  printf '    não existe: %s\n' "${ausentes[@]}"
fi

# O `.env.example` não tem `/` e por isso escapa da extração acima — e é o
# arquivo que o Passo 5 manda copiar.
afirmar_contem '.env.example' "$(cat "$DOC")" 'o documento manda partir do .env.example'
afirmar_arquivo "$RAIZ/.env.example" 'e o .env.example existe'

# ─── 2. Todo passo tem prova, e a numeração não pula ────────────────────────

mapfile -t sem_prova < <(
  awk '
    /^## / {
      if (passo != "" && !prova) print passo
      passo = ""; prova = 0
      if ($0 ~ /^## Passo /) passo = $0
      next
    }
    /^\*\*Prova:\*\*/ { prova = 1 }
    END { if (passo != "" && !prova) print passo }
  ' "$DOC"
)

mapfile -t numeros < <(grep -oE '^## Passo [0-9]+' "$DOC" | grep -oE '[0-9]+$')

if [ "${#numeros[@]}" -eq 0 ]; then
  afirmar 1 'o documento tem passo numerado'
else
  afirmar 0 "o documento tem ${#numeros[@]} passo(s) numerado(s)"
fi

if [ "${#sem_prova[@]}" -eq 0 ]; then
  afirmar 0 'todo passo termina numa prova — a promessa do próprio arquivo'
else
  afirmar 1 'todo passo termina numa prova — a promessa do próprio arquivo'
  printf '    sem "**Prova:**": %s\n' "${sem_prova[@]}"
fi

esperado=1
fora_de_ordem=0
for numero in "${numeros[@]}"; do
  [ "$numero" = "$esperado" ] || fora_de_ordem=1
  esperado=$((esperado + 1))
done
afirmar "$fora_de_ordem" 'os passos são numerados de 1 em diante, sem pular'

# ─── 3. O código de saída prometido é o que o script devolve ────────────────
# A frase do Passo 5 é lida do documento e comparada com a execução real. É
# deliberadamente presa à redação: reescrever a frase faz este caso falhar, e
# falhar aqui é o pedido para conferir de novo — não para ajustar o número.

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
cp "$FIXTURES/credenciais/duble-curl-200.sh" "$BIN/curl"
chmod +x "$BIN/curl"

# Ambiente limpo: sem credencial da máquina entrando, e sem chamada saindo.
saida="$(env -i PATH="$BIN:/usr/bin:/bin" SCULLY_SEM_ENV=1 \
  DUBLE_ARGV="$TMP/argv" DUBLE_STDIN="$TMP/stdin" \
  bash "$RAIZ/ops/verificar-credenciais.sh" 2>&1)"
status=$?

# O documento vem achatado numa linha só: a frase é presa à redação de
# propósito, não à largura da coluna em que ela coube.
declarado="$(tr '\n' ' ' <"$DOC" |
  sed -n 's/.*Sem `\.env` nenhum, a verificação sai \*\*\([0-9]\)\*\*.*/\1/p')"

afirmar_igual "$status" "$declarado" \
  'o código de saída que o Passo 5 promete é o que a verificação devolve'
afirmar_nao_contem '✅' "$saida" 'e, como o documento diz, nada aparece como verificado'
afirmar_contem '🚧' "$saida" 'tudo aparece como lacuna'

# ─── 4. A catraca do coletor ────────────────────────────────────────────────
# "Nenhum coletor está implementado" é afirmação de estado. Ela sai do arquivo
# no dia em que deixar de ser verdade, e é este caso que obriga.

mapfile -t coletores < <(git ls-files '.ai/tools/coleta/*.sh')
texto="$(cat "$DOC")"

if [ "${#coletores[@]}" -eq 0 ]; then
  afirmar_contem 'Nenhum coletor está implementado' "$texto" \
    'sem coletor, o documento declara que a trilha para antes da ronda'
else
  afirmar_nao_contem 'Nenhum coletor está implementado' "$texto" \
    "há ${#coletores[@]} coletor(es): o documento precisa deixar de dizer que não há"
fi
