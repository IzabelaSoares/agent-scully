#!/usr/bin/env python3
"""Leitor da política declarativa — o subconjunto restrito de YAML (decisões 0003).

**Uma política, um leitor.** Quem verifica a política (`tests/prazo/verificar.py`)
e quem a consome (`.ai/tools/coleta/board-radar.sh`) leem pelo mesmo código. Dois
leitores seriam pior que o problema que a política resolve: o verificador
aceitaria um arquivo que o coletor lê de outro jeito, e a divergência apareceria
como número errado no laudo — sem nada falhando.

O subconjunto é restrito de propósito: mapa aninhado, lista de escalares e
comentário, e nada mais. Sem âncora, sem coleção em linha, sem escalar de várias
linhas. O que estiver fora é recusado **com o número da linha**, em vez de lido
pela metade: `.yaml` mal escrito tem que falhar como falha, nunca virar lista
vazia — e lista vazia aqui é a fila inteira invisível (decisões 0003).

Cada escalar carrega também **onde ele está** e **se tem razão ao lado**, porque
"todo valor traz a razão" é verificado, e a verificação precisa saber a linha.

Uso como biblioteca:
    from politica import ErroDePolitica, ler_politica, simples

Uso como comando — devolve a política em JSON, para quem lê com `jq`:
    .ai/tools/lib/politica.py .ai/politicas/prazo.yaml

Status 0 com o JSON no stdout; 1 com o motivo no stderr, e nada no stdout:
política ilegível não devolve política pela metade.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

CHAVE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:(.*)$")
ITEM = re.compile(r"^-\s+(.*)$")


class ErroDePolitica(Exception):
    def __init__(self, numero: int, motivo: str) -> None:
        super().__init__(f"linha {numero}: {motivo}")
        self.numero = numero
        self.motivo = motivo


class Abertura:
    """Bloco recém-aberto: vira mapa ou lista na primeira linha de dentro.

    Quem diz se `campos:` é lista ou mapa é a linha seguinte, e não a chave —
    por isso o recipiente nasce indefinido e só então se materializa.
    """

    def __init__(self, pai: dict, nome: str) -> None:
        self.pai = pai
        self.nome = nome


class Valor:
    """Um escalar do arquivo, com onde ele está e se tem razão ao lado."""

    def __init__(self, texto: str, numero: int, com_razao: bool) -> None:
        self.texto = texto
        self.numero = numero
        self.com_razao = com_razao

    def __repr__(self) -> str:  # pragma: no cover — só ajuda em depuração
        return f"Valor({self.texto!r}, linha={self.numero})"


def _escalar(bruto: str, numero: int) -> tuple[str, bool]:
    """Devolve (valor, tem comentário ao lado). Recusa o que sai do subconjunto."""
    bruto = bruto.strip()
    if bruto.startswith(("[", "{")):
        raise ErroDePolitica(numero, "coleção em linha — use lista de bloco")
    if bruto.startswith(("&", "*")):
        raise ErroDePolitica(numero, "âncora ou alias — fora do subconjunto")
    if bruto.startswith(("|", ">")):
        raise ErroDePolitica(numero, "escalar de várias linhas — fora do subconjunto")
    if bruto.startswith("'"):
        raise ErroDePolitica(numero, "aspas simples — use aspas duplas")

    if bruto.startswith('"'):
        fim = bruto.find('"', 1)
        if fim < 0:
            raise ErroDePolitica(numero, "aspas duplas não fechadas")
        valor = bruto[1:fim]
        resto = bruto[fim + 1 :].strip()
        if resto and not resto.startswith("#"):
            raise ErroDePolitica(numero, "texto depois do valor entre aspas")
        return valor, resto.startswith("#")

    corte = bruto.find(" #")
    if corte >= 0:
        return bruto[:corte].strip(), True
    return bruto, False


def ler_politica(caminho: Path) -> tuple[dict, list[Valor]]:
    """Lê o subconjunto restrito: mapa aninhado, lista de escalares, comentário."""
    raiz: dict = {}
    valores: list[Valor] = []
    # (indentação, recipiente) — o topo da pilha é onde a próxima linha entra.
    pilha: list[tuple[int, object]] = [(-1, raiz)]
    comentario_acima = False

    for numero, linha in enumerate(caminho.read_text(encoding="utf-8").splitlines(), 1):
        if "\t" in linha:
            raise ErroDePolitica(numero, "tabulação — a indentação é de dois espaços")
        if not linha.strip():
            comentario_acima = False
            continue
        if linha.lstrip().startswith("#"):
            comentario_acima = True
            continue

        indentacao = len(linha) - len(linha.lstrip(" "))
        if indentacao % 2:
            raise ErroDePolitica(numero, "indentação ímpar — são dois espaços por nível")

        while len(pilha) > 1 and indentacao <= pilha[-1][0]:
            pilha.pop()
        conteudo = linha.strip()

        item = ITEM.match(conteudo)
        recipiente = _materializar(pilha, list if item else dict)

        if item:
            if not isinstance(recipiente, list):
                raise ErroDePolitica(numero, "item de lista fora de uma lista")
            texto, ao_lado = _escalar(item.group(1), numero)
            if not texto:
                raise ErroDePolitica(numero, "item de lista sem valor")
            valor = Valor(texto, numero, ao_lado or comentario_acima)
            recipiente.append(valor)
            valores.append(valor)
            comentario_acima = False
            continue

        chave = CHAVE.match(conteudo)
        if not chave:
            raise ErroDePolitica(numero, "nem chave nem item de lista")
        if not isinstance(recipiente, dict):
            raise ErroDePolitica(numero, "chave dentro de uma lista")

        nome, bruto = chave.group(1), chave.group(2)
        if nome in recipiente:
            raise ErroDePolitica(numero, f"chave repetida: {nome}")

        texto, ao_lado = _escalar(bruto, numero)
        if texto:
            valor = Valor(texto, numero, ao_lado or comentario_acima)
            recipiente[nome] = valor
            valores.append(valor)
            comentario_acima = False
            continue

        # Chave sem valor abre um bloco. Se ele é mapa ou lista, quem diz é a
        # primeira linha de dentro — por isso o recipiente nasce indefinido.
        recipiente[nome] = None
        pilha.append((indentacao, Abertura(recipiente, nome)))
        comentario_acima = False

    return raiz, valores


def _materializar(pilha: list, como: type) -> object:
    """Troca a `Abertura` do topo pelo recipiente que a primeira linha revelou."""
    indentacao, recipiente = pilha[-1]
    if isinstance(recipiente, Abertura):
        concreto = como()
        recipiente.pai[recipiente.nome] = concreto
        pilha[-1] = (indentacao, concreto)
        return concreto
    return recipiente


def simples(no: object) -> object:
    """A mesma estrutura, com os escalares nus — é o que vira JSON.

    Linha e razão interessam a quem **verifica** a política; a quem a **consome**
    interessa o valor. Bloco aberto e nunca preenchido vira `null`, e não `{}`:
    quem consome tem de conseguir distinguir "declarado vazio" de "declarado".
    """
    if isinstance(no, Valor):
        return no.texto
    if isinstance(no, dict):
        return {chave: simples(valor) for chave, valor in no.items()}
    if isinstance(no, list):
        return [simples(item) for item in no]
    return no


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("Uso: politica.py <arquivo.yaml>", file=sys.stderr)
        return 1

    caminho = Path(argv[0])
    if not caminho.is_file():
        print(f"política ausente: {argv[0]}", file=sys.stderr)
        return 1

    try:
        dados, _ = ler_politica(caminho)
    except ErroDePolitica as erro:
        print(f"{argv[0]} fora do subconjunto — {erro}", file=sys.stderr)
        return 1

    # `ensure_ascii=False`: o conteúdo é português, e escapar acento aqui só
    # tornaria ilegível o que a próxima pessoa vai depurar com os olhos.
    print(json.dumps(simples(dados), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
