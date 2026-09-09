#!/usr/bin/env python3
"""O que um script lê é o que o `.env.example` documenta.

A divergência entre o que o script lê e o que o exemplo documenta é o defeito
mais comum deste tipo de projeto, e o mais chato de diagnosticar: ele se
manifesta como "funciona na sua máquina" — a variável existe no `.env` de quem
escreveu e não existe no de quem clonou (TASKS B2).

Três verificações, e todas as três olham só para arquivo versionado:

  1. **Toda variável lida por script está documentada.** A lista de exceções é
     `internas.txt`, e é **fechada de propósito**: variável nova nasce
     documentada ou quebra o CI. Uma lista de inclusão (só confira o que começa
     com tal prefixo) falharia aberto — a variável nova de prefixo novo passaria
     em silêncio, que é exatamente o modo de falha a evitar.
  2. **Toda seção do exemplo traz as cinco informações** — o que é (o título e a
     descrição), em que conta, quem emite, qual escopo, qual validade — ou
     declara `Sem credencial:` com o motivo. É a informação que falta às três da
     manhã, quando uma credencial expira.
  3. **Nenhuma variável de nome de segredo tem valor.** O arquivo documenta o
     contrato, nunca o valor.

Uso:
  tests/inventario/verificar.py                       (a partir da raiz)
  tests/inventario/verificar.py --exemplo A --script B --script C

Status 0 se tudo passa; 1 se alguma verificação falha; 2 se `internas.txt`
está malformado.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent

# Os dublês inventam variável de propósito — é como o caso prova que este
# verificador sabe falhar. Varrê-los junto com o resto faria o canário derrubar
# a árvore limpa.
EXCLUIDOS = ("tests/fixtures/",)

# Seção do `.env.example`:  # ─── Título ──────────
SECAO = re.compile(r"^#\s*─{2,}\s*(.+?)\s*─{2,}\s*$")
# Variável documentada, ativa ou comentada. A comentada é como o arquivo
# documenta o que tem default e não se preenche à mão.
ATRIBUICAO = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$")
ATRIBUICAO_COMENTADA = re.compile(
    r"^\s*#\s*(?:export\s+)?([A-Z_][A-Z0-9_]*)\s*=(.*)$"
)
COMENTARIO = re.compile(r"^\s*#\s?(.*)$")

# As cinco informações. "O que é" sai do título da seção e da linha de
# descrição; as outras quatro são rótulo explícito, porque rótulo é o que se
# verifica sem adivinhar.
ROTULOS = {
    "conta": re.compile(r"(?i)\bconta\s*:"),
    "emissor": re.compile(r"(?i)\bemissor\s*:"),
    "escopo": re.compile(r"(?i)\bescopo(?:\s+mínimo)?\s*:"),
    "validade": re.compile(r"(?i)\bvalidade\s*:"),
}
SEM_CREDENCIAL = re.compile(r"(?i)\bsem\s+credencial\s*:")

# Nome que indica segredo. Valor preenchido aqui é credencial versionada, e o
# estrago é irreversível: repositório público fica em cache e em fork
# (decisões 0002).
INDICA_SEGREDO = re.compile(r"TOKEN|SECRET|SENHA|PASSWORD|_KEY|WEBHOOK|CREDENCIAL")

# Leitura de variável em shell. Nome de variável de ambiente é MAIÚSCULO neste
# repositório; local de script é minúsculo. `${#x}` e `${!x}` não casam porque
# depois da chave é exigida uma letra.
LEITURA_SH = re.compile(r"\$\{?([A-Z][A-Z0-9_]*)\b")
# Atribuída no próprio arquivo não é entrada de ambiente: é variável de trabalho.
ATRIBUICOES_SH = (
    re.compile(r"^\s*(?:export|declare|typeset|readonly|local)\s+(?:-\w+\s+)*([A-Z][A-Z0-9_]*)\b"),
    re.compile(r"^\s*([A-Z][A-Z0-9_]*)\s*="),
    re.compile(r"\bfor\s+([A-Z][A-Z0-9_]*)\s+in\b"),
    re.compile(r"\bread\s+(?:-\w+\s+)*([A-Z][A-Z0-9_]*)\b"),
    re.compile(r"\bmapfile\s+(?:-\w+\s+)*([A-Z][A-Z0-9_]*)\b"),
    re.compile(r"\bprintf\s+-v\s+([A-Z][A-Z0-9_]*)\b"),
)
LEITURAS_PY = (
    re.compile(r"""os\.environ(?:\.get)?[\[(]\s*["']([A-Za-z_][A-Za-z0-9_]*)["']"""),
    re.compile(r"""os\.getenv\(\s*["']([A-Za-z_][A-Za-z0-9_]*)["']"""),
)

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


def carregar_internas(caminho: Path) -> list[tuple[str, str]]:
    """Nomes e prefixos que um script pode ler sem estar no `.env.example`."""
    entradas: list[tuple[str, str]] = []
    for numero, linha in enumerate(caminho.read_text(encoding="utf-8").splitlines(), 1):
        if not linha.strip() or linha.lstrip().startswith("#"):
            continue
        if "\t" not in linha:
            print(
                f"✗ internas.txt:{numero} sem TAB separando nome e motivo",
                file=sys.stderr,
            )
            sys.exit(2)
        nome, motivo = linha.split("\t", 1)
        if not motivo.strip():
            print(f"✗ internas.txt:{numero} sem motivo", file=sys.stderr)
            sys.exit(2)
        entradas.append((nome.strip(), motivo.strip()))
    return entradas


def e_interna(nome: str, entradas: list[tuple[str, str]]) -> bool:
    for padrao, _ in entradas:
        if padrao.endswith("*"):
            if nome.startswith(padrao[:-1]):
                return True
        elif nome == padrao:
            return True
    return False


class Secao:
    def __init__(self, titulo: str) -> None:
        self.titulo = titulo
        self.comentarios: list[str] = []
        self.variaveis: list[str] = []


def ler_exemplo(caminho: Path) -> tuple[list[Secao], dict[str, str], list[str]]:
    """Devolve as seções, o valor de cada variável e as variáveis fora de seção."""
    secoes: list[Secao] = []
    valores: dict[str, str] = {}
    fora_de_secao: list[str] = []
    atual: Secao | None = None

    for linha in caminho.read_text(encoding="utf-8").splitlines():
        cabecalho = SECAO.match(linha)
        if cabecalho:
            atual = Secao(cabecalho.group(1))
            secoes.append(atual)
            continue

        comentada = linha.lstrip().startswith("#")
        atribuicao = ATRIBUICAO_COMENTADA.match(linha) if comentada else ATRIBUICAO.match(linha)
        if atribuicao is None:
            comentario = COMENTARIO.match(linha)
            if comentario and atual is not None:
                atual.comentarios.append(comentario.group(1))
            continue

        nome, valor = atribuicao.group(1), atribuicao.group(2)
        valores[nome] = valor.strip()
        if atual is None:
            fora_de_secao.append(nome)
        else:
            atual.variaveis.append(nome)

    return secoes, valores, fora_de_secao


def sem_valor(bruto: str) -> bool:
    valor = bruto.strip()
    if valor in ("", "''", '""'):
        return True
    # Placeholder entre <> é contrato, não valor: ninguém autentica com ele.
    return "<" in valor and ">" in valor


def scripts_rastreados() -> list[Path]:
    saida = subprocess.run(
        ["git", "-C", str(RAIZ), "ls-files", "-z", "*.sh", "*.py"],
        capture_output=True,
        check=True,
        text=True,
    ).stdout
    caminhos = []
    for relativo in filter(None, saida.split("\0")):
        if relativo.startswith(EXCLUIDOS):
            continue
        caminho = RAIZ / relativo
        if caminho.is_symlink() or not caminho.is_file():
            continue
        caminhos.append(caminho)
    return caminhos


def variaveis_lidas(caminho: Path) -> set[str]:
    try:
        texto = caminho.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return set()

    if caminho.suffix == ".py":
        lidas: set[str] = set()
        for regex in LEITURAS_PY:
            lidas.update(regex.findall(texto))
        return lidas

    atribuidas: set[str] = set()
    for linha in texto.splitlines():
        for regex in ATRIBUICOES_SH:
            atribuidas.update(regex.findall(linha))
    return set(LEITURA_SH.findall(texto)) - atribuidas


def main() -> int:
    argumentos = argparse.ArgumentParser(add_help=True)
    argumentos.add_argument("--exemplo", default=str(RAIZ / ".env.example"))
    argumentos.add_argument("--internas", default=str(AQUI / "internas.txt"))
    argumentos.add_argument("--script", action="append", default=[])
    opcoes = argumentos.parse_args()

    exemplo = Path(opcoes.exemplo)
    if not exemplo.is_file():
        print(f"✗ inventário: {opcoes.exemplo} não existe")
        return 1

    internas = carregar_internas(Path(opcoes.internas))
    # Lista vazia passaria em tudo e não protegeria nada — é o modo de falha
    # mais perigoso de um teste de negação (mesma razão do canário da
    # sanitização).
    afirmar(len(internas) > 0, f"internas.txt tem entrada carregada ({len(internas)})")

    secoes, valores, fora_de_secao = ler_exemplo(exemplo)
    afirmar(len(valores) > 0, f"{exemplo.name} documenta variável ({len(valores)})")
    afirmar(
        not fora_de_secao,
        "toda variável documentada está sob uma seção"
        + (f" — fora: {', '.join(fora_de_secao)}" if fora_de_secao else ""),
    )

    # 1. As cinco informações, por seção.
    incompletas: list[str] = []
    for secao in secoes:
        if not secao.variaveis:
            continue
        texto = "\n".join(secao.comentarios)
        if SEM_CREDENCIAL.search(texto):
            continue
        faltando = [nome for nome, regex in ROTULOS.items() if not regex.search(texto)]
        descricao = [
            linha
            for linha in secao.comentarios
            if linha.strip() and not any(r.search(linha) for r in ROTULOS.values())
        ]
        if not descricao:
            faltando.append("o que é (nenhuma linha de descrição)")
        if faltando:
            incompletas.append(f"{secao.titulo} — falta: {', '.join(faltando)}")

    afirmar(
        not incompletas,
        "toda seção traz as cinco informações, ou declara não ter credencial"
        + (f" — {len(incompletas)} seção(ões) incompleta(s)" if incompletas else ""),
    )
    for achado in incompletas:
        print(f"    {achado}")

    # 2. Nenhum valor onde o nome indica segredo.
    preenchidas = [
        nome
        for nome, valor in valores.items()
        if INDICA_SEGREDO.search(nome) and not sem_valor(valor)
    ]
    afirmar(
        not preenchidas,
        "nenhuma variável de nome de segredo tem valor no exemplo"
        + (f" — {', '.join(preenchidas)}" if preenchidas else ""),
    )

    # 3. O que os scripts leem está documentado.
    if opcoes.script:
        scripts = [Path(caminho) for caminho in opcoes.script]
    else:
        scripts = scripts_rastreados()

    nao_documentadas: list[str] = []
    for script in scripts:
        for nome in sorted(variaveis_lidas(script)):
            if nome in valores or e_interna(nome, internas):
                continue
            relativo = script.resolve()
            try:
                relativo = relativo.relative_to(RAIZ)
            except ValueError:
                pass
            nao_documentadas.append(f"{relativo} lê {nome}")

    afirmar(
        not nao_documentadas,
        f"toda variável lida pelos {len(scripts)} script(s) está no {exemplo.name}"
        + (f" — {len(nao_documentadas)} ausente(s)" if nao_documentadas else ""),
    )
    for achado in nao_documentadas:
        print(f"    {achado}")
    if nao_documentadas:
        print(
            "\n  Documente a variável no .env.example — com o que é, em que conta,\n"
            "  quem emite, qual escopo e qual validade. Sendo interna à execução\n"
            "  e não configuração, a exceção vai para tests/inventario/internas.txt\n"
            "  com o motivo ao lado.",
        )

    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
