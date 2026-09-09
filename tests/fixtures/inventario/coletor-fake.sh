#!/usr/bin/env bash
#
# Dublê. NÃO é coletor: não coleta nada e nunca é executado pela suíte.
#
# Existe para provar que o verificador de inventário pega uma variável lida por
# script e ausente do `.env.example`. Teste de negação que só roda sobre árvore
# limpa não prova nada sobre o dia em que a árvore não estiver limpa — mesma
# razão do canário de tests/casos/00-sanitizacao.sh.

set -uo pipefail

printf 'base: %s\n' "${FIXTURE_FONTE_BASE_URL:-}"
printf 'tem credencial: %s\n' "${FIXTURE_FONTE_API_TOKEN:+sim}"
