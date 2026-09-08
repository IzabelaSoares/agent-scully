#!/usr/bin/env python3
"""Todo link interno da documentação resolve.

Link quebrado em documentação de agente não é cosmético: o agente segue o link,
não encontra o arquivo, e segue sem o contexto que a instrução mandava carregar.

**A regra de base do caminho tem uma exceção, e ela é deliberada.**
`.ai/INSTRUCTIONS.md` é lido através do symlink `CLAUDE.md`, que está na raiz, e
por isso seus links são relativos à **raiz do repositório**. Todo o resto usa
caminho relativo ao próprio arquivo, que é o que o GitHub renderiza. Ver
.ai/CONVENTIONS.md.

Uso: tests/verificar-links.py   (a partir da raiz do repositório)
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# Lidos através dos symlinks da raiz: base é a raiz, não o diretório do arquivo.
BASE_NA_RAIZ = {".ai/INSTRUCTIONS.md"}

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
EXTERNO = re.compile(r"^(?:https?:|mailto:|#)")

ok = 0
falhas = 0


def markdowns() -> list[str]:
    saida = subprocess.run(
        ["git", "-C", str(RAIZ), "ls-files", "-z", "*.md"],
        capture_output=True,
        check=True,
        text=True,
    ).stdout
    return [p for p in filter(None, saida.split("\0")) if not (RAIZ / p).is_symlink()]


def alvos(relativo: str) -> list[tuple[int, str]]:
    """Links internos do arquivo, ignorando bloco de código cercado."""
    encontrados = []
    dentro_de_codigo = False
    texto = (RAIZ / relativo).read_text(encoding="utf-8")
    for numero, linha in enumerate(texto.splitlines(), 1):
        if linha.lstrip().startswith("```"):
            dentro_de_codigo = not dentro_de_codigo
            continue
        if dentro_de_codigo:
            continue
        for alvo in LINK.findall(linha):
            if EXTERNO.match(alvo) or alvo.startswith("<"):
                continue
            encontrados.append((numero, alvo))
    return encontrados


def main() -> int:
    global ok, falhas
    arquivos = markdowns()
    if not arquivos:
        print("✗ nenhum markdown rastreado encontrado")
        return 1

    quebrados: list[str] = []
    total = 0

    for relativo in arquivos:
        base = RAIZ if relativo in BASE_NA_RAIZ else (RAIZ / relativo).parent
        for numero, alvo in alvos(relativo):
            total += 1
            caminho = (base / alvo.split("#", 1)[0]).resolve()
            if not caminho.exists():
                quebrados.append(f"{relativo}:{numero} → {alvo}")

    if quebrados:
        print(f"✗ {len(quebrados)} link(s) interno(s) quebrado(s) de {total}")
        for q in quebrados:
            print(f"    {q}")
        falhas += 1
    else:
        print(f"✓ todos os {total} links internos resolvem")
        ok += 1

    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
