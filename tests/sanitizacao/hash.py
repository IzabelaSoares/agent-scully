#!/usr/bin/env python3
"""Imprime a linha de hash a colar em tokens.sha256.

Uso: tests/sanitizacao/hash.py <termo> [<termo> ...]

Um termo é um token: sequência alfanumérica única, minúscula. `foo-bar` não é um
termo — `foo` e `bar` são. Ver tests/sanitizacao/README.md.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
sys.path.insert(0, str(RAIZ))
from verificar import SAL, hash_token  # noqa: E402

if len(sys.argv) < 2:
    print(__doc__.strip(), file=sys.stderr)
    sys.exit(2)

for bruto in sys.argv[1:]:
    termo = bruto.strip().lower()
    if not re.fullmatch(r"[a-z0-9]+", termo):
        print(
            f"recusado: {bruto!r} não é um token alfanumérico único — "
            "quebre em partes (ver README.md)",
            file=sys.stderr,
        )
        sys.exit(1)
    print(hash_token(termo))

print(f"\n# sal em uso: {SAL!r}", file=sys.stderr)
