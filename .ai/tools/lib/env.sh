#!/usr/bin/env bash
#
# Biblioteca de ambiente — carrega o `.env` SEM sobrescrever o ambiente.
#
# Biblioteca: use com `source`, não execute.
#
# ⚠️ Não use `set -a; source .env`. O arquivo ganha do ambiente, e as duas
# consequências estão na SPEC §10: `TOKEN=invalido ./script` é silenciosamente
# ignorado — o caminho de falha vira intestável — e segredo injetado por
# variável (CI, export manual) é descartado sem aviso.
#
# Por isso o arquivo é lido linha a linha, nunca interpretado pelo shell:
#   - o `&` de uma URL de webhook não vira separador de job (SPEC §10);
#   - `$(...)` e `` ` `` dentro de um valor não executam nada;
#   - o ambiente ganha, sempre.
#
# Uso:
#   . "$RAIZ/.ai/tools/lib/env.sh"
#   ambiente_carregar                    # lê ./.env
#   ambiente_carregar caminho/outro.env  # lê outro arquivo
#
# Status != 0 quando o arquivo existe e tem linha malformada. Arquivo ausente
# não é erro: é a máquina que ainda não foi configurada, e quem precisa da
# variável reclama na hora de usá-la.
#
# `SCULLY_SEM_ENV=1` ignora o arquivo por completo — é o que dá à suíte
# isolamento do `.env` da máquina.

# Precedência: variável já DEFINIDA no shell ou no ambiente ganha do arquivo,
# **inclusive quando está vazia**. Definida-e-vazia é escolha de quem chamou
# (`TOKEN= ./script`, para exercitar o caminho sem credencial), e deixar o
# arquivo repreenchê-la devolveria pela porta dos fundos a armadilha que esta
# biblioteca existe para fechar.
ambiente_carregar() {
  local arquivo="${1:-.env}"
  local linha numero=0 chave valor malformadas=0

  [ "${SCULLY_SEM_ENV:-}" = "1" ] && return 0
  [ -f "$arquivo" ] || return 0

  # `|| [ -n "$linha" ]` lê também a última linha sem quebra no final.
  while IFS= read -r linha || [ -n "$linha" ]; do
    numero=$((numero + 1))

    # Comentário e linha em branco não são dados.
    case "$linha" in
      '' | '#'*) continue ;;
    esac
    # Linha só com espaço em branco também não.
    [ -z "${linha//[[:space:]]/}" ] && continue

    # `export CHAVE=valor` é aceito: é como muita gente escreve o arquivo.
    linha="${linha#export }"

    if [[ "$linha" != *=* ]]; then
      # Só o número da linha. O conteúdo pode ser um segredo, e mensagem de
      # erro é a rota de vazamento mais fácil de esquecer.
      printf 'env: linha %s de %s não tem "=" — ignorada\n' "$numero" "$arquivo" >&2
      malformadas=$((malformadas + 1))
      continue
    fi

    chave="${linha%%=*}"
    valor="${linha#*=}"
    # Espaço em volta do nome é digitação, não parte do nome.
    chave="${chave#"${chave%%[![:space:]]*}"}"
    chave="${chave%"${chave##*[![:space:]]}"}"

    if [[ ! "$chave" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      printf 'env: linha %s de %s não tem nome de variável válido — ignorada\n' \
        "$numero" "$arquivo" >&2
      malformadas=$((malformadas + 1))
      continue
    fi

    # Aspas: o par externo delimita e sai. Dentro dele, tudo é literal — não há
    # expansão de variável nem de comando, de propósito. Sem aspas, o valor é a
    # linha inteira depois do `=`, aparada nas pontas; `#` no meio de um valor
    # sem aspas é valor, não comentário, porque adivinhar aqui erra em silêncio.
    case "$valor" in
      \'*\')
        [ "${#valor}" -ge 2 ] && valor="${valor:1:${#valor}-2}"
        ;;
      \"*\")
        [ "${#valor}" -ge 2 ] && valor="${valor:1:${#valor}-2}"
        ;;
      *)
        valor="${valor#"${valor%%[![:space:]]*}"}"
        valor="${valor%"${valor##*[![:space:]]}"}"
        ;;
    esac

    # O ambiente ganha. `+` testa DEFINIDA, não "não vazia" — ver o comentário
    # de precedência acima.
    if [ -n "${!chave+definida}" ]; then
      continue
    fi

    export "${chave}=${valor}"
  done <"$arquivo"

  [ "$malformadas" -eq 0 ] || return 1
  return 0
}

# Executada em vez de carregada: avisa e sai != 0, em vez de não fazer nada.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  printf 'env.sh é biblioteca: use `. %s` e chame ambiente_carregar.\n' \
    "${BASH_SOURCE[0]}" >&2
  exit 2
fi
