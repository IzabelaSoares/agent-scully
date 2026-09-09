#!/usr/bin/env bash
#
# A biblioteca de ambiente: o AMBIENTE ganha do arquivo, e o arquivo nunca é
# interpretado pelo shell.
#
# As duas primeiras armadilhas da SPEC §10 são exatamente isto — `set -a;
# source .env` deixando o arquivo ganhar, e o `&` de uma URL de webhook virando
# separador de job. Este caso é a rede que impede as duas de voltarem.
#
# Sem ele, todo teste de "a fonte caiu" escrito daqui em diante rodaria com a
# credencial boa do arquivo e passaria por engano (TASKS B1).

set -uo pipefail
cd "$RAIZ" || exit 1
# shellcheck source=/dev/null
. "$RAIZ/tests/helpers.sh"

LIB="$RAIZ/.ai/tools/lib/env.sh"
FIX="$FIXTURES/ambiente"
export LIB FIX

afirmar_arquivo "$LIB" "existe: .ai/tools/lib/env.sh"
afirmar_arquivo "$FIX/basico.env" "existe o dublê de .env"

# Cada trecho roda num bash próprio, sem o SCULLY_SEM_ENV que o run.sh exporta:
# é o único jeito de testar o carregamento sem desligar o isolamento da suíte.
executar() {
  # executar <VAR=valor...> -- <trecho>
  local -a ambiente=()
  while [ "$1" != '--' ]; do
    ambiente+=("$1")
    shift
  done
  shift
  env -u SCULLY_SEM_ENV LIB="$LIB" FIX="$FIX" "${ambiente[@]}" bash -c "
    set -uo pipefail
    . \"\$LIB\"
    $1"
}

# ─── 1. O ambiente ganha do arquivo ─────────────────────────────────────────

obtido="$(executar SCULLY_T_PRECEDENCIA=injetada -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_PRECEDENCIA"')"
afirmar_igual 'injetada' "$obtido" \
  'variável injetada no ambiente ganha do .env'

# Definida-e-vazia também é escolha de quem chamou: é assim que se exercita o
# caminho sem credencial. Deixar o arquivo repreencher devolveria a armadilha.
obtido="$(executar SCULLY_T_PRECEDENCIA_VAZIA= -- \
  'ambiente_carregar "$FIX/basico.env"; printf "[%s]" "$SCULLY_T_PRECEDENCIA_VAZIA"')"
afirmar_igual '[]' "$obtido" \
  'variável definida e VAZIA no ambiente também ganha do .env'

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_PRECEDENCIA"')"
afirmar_igual 'valor-do-arquivo' "$obtido" \
  'sem nada no ambiente, o valor do arquivo é usado'

# ─── 2. Valor com `&`, `?` e espaço sobrevive ───────────────────────────────

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_ASPAS_SIMPLES"')"
afirmar_igual 'https://exemplo.invalido/hook?a=1&b=2 c' "$obtido" \
  'valor com &, ? e espaço chega inteiro (aspas simples)'

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_ASPAS_DUPLAS"')"
afirmar_igual 'com espaço e # cerquilha' "$obtido" \
  'aspas duplas delimitam e saem; cerquilha dentro é valor'

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_SEM_EXPANSAO"')"
afirmar_igual '$HOME e $(uname) e `id`' "$obtido" \
  'o arquivo não é interpretado: nada expande, nada executa'

# ─── 3. SCULLY_SEM_ENV=1 ignora o arquivo por completo ──────────────────────

obtido="$(executar SCULLY_SEM_ENV=1 -- \
  'ambiente_carregar "$FIX/basico.env"; printf "[%s]" "${SCULLY_T_SIMPLES:-}"')"
afirmar_igual '[]' "$obtido" \
  'SCULLY_SEM_ENV=1 ignora o arquivo por completo'

executar SCULLY_SEM_ENV=1 -- 'ambiente_carregar "$FIX/malformado.env"' 2>/dev/null
afirmar $? 'SCULLY_SEM_ENV=1 sai 0 mesmo com arquivo malformado (nem lê)'

# ─── 4. O resto do contrato de parsing ──────────────────────────────────────

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_CERQUILHA"')"
afirmar_igual 'a#b' "$obtido" \
  'sem aspas, cerquilha no meio do valor é valor, não comentário'

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_ESPACADA"')"
afirmar_igual 'com-espaco-em-volta' "$obtido" \
  'espaço em volta do nome e do valor é aparado'

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "%s" "$SCULLY_T_COM_EXPORT"')"
afirmar_igual 'veio-com-export' "$obtido" \
  '`export CHAVE=valor` é aceito'

obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; printf "[%s]" "${SCULLY_T_VAZIA?nao definida}"')"
afirmar_igual '[]' "$obtido" \
  'chave sem valor no arquivo vira variável definida e vazia'

# A variável tem que chegar ao processo filho, não só ao shell que carregou.
obtido="$(executar -- \
  'ambiente_carregar "$FIX/basico.env"; env | grep "^SCULLY_T_SIMPLES="')"
afirmar_igual 'SCULLY_T_SIMPLES=valor-simples' "$obtido" \
  'a variável é exportada, e alcança o processo filho'

# ─── 5. Falha se anuncia ────────────────────────────────────────────────────

executar -- 'ambiente_carregar "$FIX/nao-existe.env"' 2>/dev/null
afirmar $? 'arquivo ausente não é erro: sai 0'

erro="$(executar -- 'ambiente_carregar "$FIX/malformado.env"' 2>&1 >/dev/null)"

if executar -- 'ambiente_carregar "$FIX/malformado.env"' >/dev/null 2>&1; then
  afirmar 1 'linha malformada faz o carregamento sair != 0'
else
  afirmar 0 'linha malformada faz o carregamento sair != 0'
fi

obtido="$(executar -- \
  'ambiente_carregar "$FIX/malformado.env" 2>/dev/null; printf "%s" "$SCULLY_T_BOA"')"
afirmar_igual 'carregou' "$obtido" \
  'linha malformada não impede as linhas boas de carregarem'

# A mensagem de erro cita a linha pelo NÚMERO. Citar o conteúdo transformaria
# stderr em rota de vazamento de credencial no dia em que a linha torta for a
# do token.
afirmar_contem 'linha 5' "$erro" 'o erro diz em que linha está o problema'
afirmar_contem 'linha 7' "$erro" 'e reporta cada linha torta, não só a primeira'
afirmar_nao_contem 'isto-nao-tem-igual' "$erro" \
  'o erro NÃO imprime o conteúdo da linha (stderr não é rota de vazamento)'
afirmar_nao_contem 'nome com hífen' "$erro" \
  'o erro de nome inválido também não imprime o valor'

# ─── 6. É biblioteca, e diz isso quando é executada ─────────────────────────

saida="$(env -u SCULLY_SEM_ENV bash "$LIB" 2>&1)"
status=$?
afirmar_igual '2' "$status" 'executar a biblioteca em vez de carregá-la sai 2'
afirmar_contem 'biblioteca' "$saida" 'e explica que é para usar com `source`'
