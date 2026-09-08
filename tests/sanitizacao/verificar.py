#!/usr/bin/env python3
"""Verifica que nenhum identificador de origem privada entrou no repositório.

Duas metades, e a razão da divisão está em tests/sanitizacao/README.md:

  padroes.txt      classes reconhecíveis pela forma, em texto claro
  tokens.sha256    literais, como hash salgado — pega o termo sem publicá-lo

⚠️ A falha reporta arquivo e linha, NUNCA o termo encontrado. Log de CI de
repositório público é público, e um teste que imprime o que encontrou publica
exatamente o que a lista existe para não publicar.

Uso: tests/sanitizacao/verificar.py            (a partir da raiz do repositório)
Status 0 se nada foi encontrado; 1 se algo foi.
"""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

# Sal público. Isto é obfuscação, não sigilo — ver README.md desta pasta.
SAL = "agent-scully/sanitizacao/v1"

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent

# O próprio diretório de verificação sai da varredura: padroes.txt contém, por
# definição, os padrões que ele procura, e casaria consigo mesmo.
EXCLUIDOS = ("tests/sanitizacao/",)

TOKEN = re.compile(r"[A-Za-z0-9]+")

ok = 0
falhas = 0


def afirmar(condicao: bool, mensagem: str) -> None:
    global ok, falhas
    if condicao:
        ok += 1
        print(f"✓ {mensagem}")
    else:
        falhas += 1
        print(f"✗ {mensagem}")


def hash_token(termo: str) -> str:
    return hashlib.sha256(f"{SAL}:{termo}".encode()).hexdigest()


def carregar_padroes(caminho: Path) -> list[tuple[re.Pattern[str], str]]:
    padroes: list[tuple[re.Pattern[str], str]] = []
    for numero, linha in enumerate(caminho.read_text(encoding="utf-8").splitlines(), 1):
        linha = linha.rstrip("\n")
        if not linha.strip() or linha.lstrip().startswith("#"):
            continue
        if "\t" not in linha:
            print(
                f"✗ padroes.txt:{numero} sem TAB separando regex e motivo",
                file=sys.stderr,
            )
            sys.exit(2)
        regex, motivo = linha.split("\t", 1)
        try:
            padroes.append((re.compile(regex), motivo.strip()))
        except re.error as erro:
            print(f"✗ padroes.txt:{numero} regex inválida — {erro}", file=sys.stderr)
            sys.exit(2)
    return padroes


def carregar_tokens(caminho: Path) -> set[str]:
    proibidos = set()
    for linha in caminho.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#"):
            continue
        proibidos.add(linha.lower())
    return proibidos


def arquivos_rastreados() -> list[Path]:
    saida = subprocess.run(
        ["git", "-C", str(RAIZ), "ls-files", "-z"],
        capture_output=True,
        check=True,
        text=True,
    ).stdout
    caminhos = []
    for relativo in filter(None, saida.split("\0")):
        if relativo.startswith(EXCLUIDOS):
            continue
        caminho = RAIZ / relativo
        # Symlink aponta para arquivo já rastreado: varrer duas vezes só
        # duplicaria achado.
        if caminho.is_symlink() or not caminho.is_file():
            continue
        caminhos.append(caminho)
    return caminhos


def texto_de(caminho: Path) -> list[str] | None:
    """Devolve as linhas, ou None se o arquivo for binário."""
    try:
        bruto = caminho.read_bytes()
    except OSError:
        return None
    if b"\0" in bruto[:8192]:
        return None
    try:
        return bruto.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        return None


def main() -> int:
    padroes = carregar_padroes(AQUI / "padroes.txt")
    proibidos = carregar_tokens(AQUI / "tokens.sha256")

    # Autoverificação: lista vazia passaria em tudo e não protegeria nada. É o
    # modo de falha mais perigoso de um teste de negação.
    afirmar(len(padroes) > 0, f"padroes.txt tem padrão carregado ({len(padroes)})")
    afirmar(len(proibidos) > 0, f"tokens.sha256 tem termo carregado ({len(proibidos)})")
    afirmar(
        all(re.fullmatch(r"[0-9a-f]{64}", h) for h in proibidos),
        "todo termo em tokens.sha256 é um sha256 válido",
    )

    arquivos = arquivos_rastreados()
    afirmar(len(arquivos) > 0, f"há arquivo rastreado a varrer ({len(arquivos)})")

    achados_padrao: list[str] = []
    achados_token: list[str] = []

    for caminho in arquivos:
        linhas = texto_de(caminho)
        if linhas is None:
            continue
        relativo = caminho.relative_to(RAIZ)
        for numero, linha in enumerate(linhas, 1):
            for regex, motivo in padroes:
                if regex.search(linha):
                    achados_padrao.append(f"{relativo}:{numero} — {motivo}")
            for bruto in TOKEN.findall(linha):
                if len(bruto) < 3:
                    continue
                if hash_token(bruto.lower()) in proibidos:
                    achados_token.append(f"{relativo}:{numero}")

    afirmar(
        not achados_padrao,
        f"nenhum padrão proibido no repositório rastreado"
        + (f" — {len(achados_padrao)} achado(s)" if achados_padrao else ""),
    )
    for achado in achados_padrao:
        print(f"    {achado}")

    afirmar(
        not achados_token,
        "nenhum termo proibido no repositório rastreado"
        + (f" — {len(achados_token)} achado(s)" if achados_token else ""),
    )
    for achado in dict.fromkeys(achados_token):
        print(f"    {achado} — termo proibido (não impresso de propósito)")

    if achados_padrao or achados_token:
        print(
            "\n  O termo não é impresso porque log de CI de repositório público\n"
            "  é público. Abra o arquivo na linha indicada.",
        )

    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
