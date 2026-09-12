#!/usr/bin/env python3
"""A política de prazo é dado, e é a única fonte (TASKS C1, decisões 0003).

Quatro verificações, e cada uma existe por um modo de falha conhecido:

  1. **O arquivo é legível no subconjunto declarado.** Mapa aninhado, lista de
     escalares e comentário — nada mais. O que estiver fora é recusado com o
     número da linha, em vez de lido pela metade: `.yaml` mal escrito tem que
     falhar como falha, nunca como lista vazia (decisões 0003, "consequências
     ruins, e assumidas").
  2. **A estrutura fecha.** Toda origem tem lista de campos não vazia e um
     fallback declarado; o padrão de origem existe; o campo de corroboração
     **não** aparece em nenhuma lista de precedência — ele corrobora e nunca
     decide.
  3. **Toda linha de valor traz a razão** ao lado ou imediatamente acima. Valor
     sem razão é valor que a próxima pessoa não sabe ajustar, e que por isso
     fica errado por inércia.
  4. **Nenhum nome de campo de prazo aparece literal em script**, e a tabela de
     `.ai/docs/prazo.md` é a que sai deste arquivo. As duas metades da mesma
     regra: a política é a única fonte, e o resto é gerado ou proibido.

Uso:
  tests/prazo/verificar.py                          (a partir da raiz)
  tests/prazo/verificar.py --politica A --doc B --script C
  tests/prazo/verificar.py --gerar                  (regrava a tabela do doc)

Status 0 se tudo passa; 1 se alguma verificação falha.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent

# Os dublês são políticas quebradas de propósito — é como o caso prova que este
# verificador sabe falhar. Varrê-los junto com o resto faria o canário derrubar
# a árvore limpa (mesma exclusão de tests/inventario/verificar.py).
EXCLUIDOS = ("tests/fixtures/",)

MARCADOR_INICIO = "<!-- tabela gerada de .ai/politicas/prazo.yaml — não edite à mão -->"
MARCADOR_FIM = "<!-- fim da tabela gerada -->"

CHAVE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:(.*)$")
ITEM = re.compile(r"^-\s+(.*)$")

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


def caminho_relativo(caminho: Path) -> str:
    try:
        return str(caminho.resolve().relative_to(RAIZ))
    except ValueError:
        return str(caminho)


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


def texto(valor: object) -> str:
    return valor.texto if isinstance(valor, Valor) else ""


def tabela(dados: dict) -> str:
    """A tabela do `.ai/docs/prazo.md`, gerada da política. Fonte única."""
    origem = dados.get("origem") or {}
    origens = dados.get("origens") or {}
    modos = dados.get("modos_de_fallback") or {}
    corroboracao = dados.get("corroboracao") or {}

    linhas = [
        "| Origem | Precedência dos campos de prazo | Sem nenhum preenchido |",
        "|---|---|---|",
    ]
    for nome, conteudo in origens.items():
        campos = (conteudo or {}).get("campos") or []
        precedencia = " · ".join(
            f"{posicao}. `{texto(campo)}`" for posicao, campo in enumerate(campos, 1)
        )
        fallback = texto((conteudo or {}).get("fallback"))
        linhas.append(f"| `{nome}` | {precedencia} | `{fallback}` |")

    linhas.append("")
    linhas.append(
        f"A origem sai do campo `{texto(origem.get('campo'))}`; vazio, vale "
        f"`{texto(origem.get('padrao'))}`."
    )
    for rotulo, descricao in modos.items():
        linhas.append(f"Fallback `{rotulo}`: {texto(descricao)}.")
    linhas.append(
        f"Corrobora, e nunca decide: `{texto(corroboracao.get('campo'))}`."
    )
    return "\n".join(linhas)


def bloco_do_doc(conteudo: str) -> str | None:
    inicio = conteudo.find(MARCADOR_INICIO)
    fim = conteudo.find(MARCADOR_FIM)
    if inicio < 0 or fim < 0 or fim < inicio:
        return None
    return conteudo[inicio + len(MARCADOR_INICIO) : fim].strip("\n")


def gerar(doc: Path, esperado: str) -> int:
    conteudo = doc.read_text(encoding="utf-8")
    if bloco_do_doc(conteudo) is None:
        print(f"✗ {caminho_relativo(doc)} não tem os marcadores da tabela gerada")
        return 1
    inicio = conteudo.find(MARCADOR_INICIO) + len(MARCADOR_INICIO)
    fim = conteudo.find(MARCADOR_FIM)
    novo = conteudo[:inicio] + "\n\n" + esperado + "\n\n" + conteudo[fim:]
    doc.write_text(novo, encoding="utf-8")
    print(f"✓ tabela de {caminho_relativo(doc)} regravada a partir da política")
    return 0


def main() -> int:
    argumentos = argparse.ArgumentParser(add_help=True)
    argumentos.add_argument("--politica", default=str(RAIZ / ".ai/politicas/prazo.yaml"))
    argumentos.add_argument("--doc", default=str(RAIZ / ".ai/docs/prazo.md"))
    argumentos.add_argument("--script", action="append", default=[])
    argumentos.add_argument("--gerar", action="store_true")
    opcoes = argumentos.parse_args()

    politica = Path(opcoes.politica)
    if not politica.is_file():
        print(f"✗ política ausente: {opcoes.politica}")
        return 1

    try:
        dados, valores = ler_politica(politica)
    except ErroDePolitica as erro:
        print(f"✗ {caminho_relativo(politica)} fora do subconjunto — {erro}")
        return 1
    afirmar(True, f"{caminho_relativo(politica)} é legível no subconjunto declarado")

    # ─── Estrutura ──────────────────────────────────────────────────────────

    origem = dados.get("origem")
    origens = dados.get("origens")
    modos = dados.get("modos_de_fallback")
    corroboracao = dados.get("corroboracao")

    afirmar(isinstance(dados.get("versao"), Valor), "a política declara a versão do formato")
    afirmar(
        isinstance(origens, dict) and len(origens) > 0,
        "a política declara origem de bug" + ("" if origens else " — nenhuma declarada"),
    )
    afirmar(
        isinstance(modos, dict) and len(modos) > 0,
        "a política declara modo de fallback",
    )

    sem_campos: list[str] = []
    fallback_indefinido: list[str] = []
    for nome, conteudo in (origens or {}).items():
        campos = (conteudo or {}).get("campos") if isinstance(conteudo, dict) else None
        if not isinstance(campos, list) or not campos:
            sem_campos.append(nome)
            continue
        nomes = [texto(campo) for campo in campos]
        if len(set(nomes)) != len(nomes):
            sem_campos.append(f"{nome} (campo repetido)")
        fallback = texto((conteudo or {}).get("fallback"))
        if fallback not in (modos or {}):
            fallback_indefinido.append(f"{nome} → {fallback or '(nenhum)'}")

    afirmar(
        not sem_campos,
        "toda origem tem lista de campos não vazia e sem repetição"
        + (f" — {', '.join(sem_campos)}" if sem_campos else ""),
    )
    afirmar(
        not fallback_indefinido,
        "todo fallback de origem está declarado em modos_de_fallback"
        + (f" — {', '.join(fallback_indefinido)}" if fallback_indefinido else ""),
    )

    padrao = texto((origem or {}).get("padrao"))
    afirmar(
        padrao in (origens or {}),
        f"a origem padrão ({padrao or 'nenhuma'}) é uma das origens declaradas",
    )
    rotulos = (origem or {}).get("valores")
    desconhecidos = [
        f"{rotulo} → {texto(valor)}"
        for rotulo, valor in (rotulos or {}).items()
        if texto(valor) not in (origens or {})
    ]
    afirmar(
        isinstance(rotulos, dict) and len(rotulos) > 0 and not desconhecidos,
        "todo valor do campo de origem cai numa origem declarada"
        + (f" — {', '.join(desconhecidos)}" if desconhecidos else ""),
    )

    # O numérico de corroboração decidindo é o defeito que reporta "estourado"
    # num bug que vence hoje à tarde: o board o recalcula na própria cadência.
    campo_corroboracao = texto((corroboracao or {}).get("campo"))
    de_prazo = [
        texto(campo)
        for conteudo in (origens or {}).values()
        for campo in ((conteudo or {}).get("campos") or [])
    ]
    afirmar(
        bool(campo_corroboracao) and campo_corroboracao not in de_prazo,
        "o campo de corroboração não decide: está fora de toda precedência",
    )

    # ─── A razão ao lado ────────────────────────────────────────────────────

    sem_razao = [valor for valor in valores if not valor.com_razao]
    afirmar(
        not sem_razao,
        f"todo valor ({len(valores)}) traz a razão ao lado ou acima"
        + (f" — {len(sem_razao)} sem razão" if sem_razao else ""),
    )
    for valor in sem_razao:
        print(f"    {caminho_relativo(politica)}:{valor.numero} sem razão")

    # ─── Nenhum nome de campo literal em script ─────────────────────────────

    nomeados = set(de_prazo)
    nomeados.add(texto((origem or {}).get("campo")))
    nomeados.add(campo_corroboracao)
    campos_declarados = sorted(nome for nome in nomeados if nome)
    scripts = (
        [Path(caminho) for caminho in opcoes.script]
        if opcoes.script
        else scripts_rastreados()
    )
    literais: list[str] = []
    for script in scripts:
        try:
            linhas = script.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        for numero, linha in enumerate(linhas, 1):
            for campo in campos_declarados:
                if campo in linha:
                    literais.append(f"{caminho_relativo(script)}:{numero} cita um campo")

    afirmar(
        bool(campos_declarados),
        f"a política nomeia campo de prazo ({len(campos_declarados)})",
    )
    afirmar(
        not literais,
        f"nenhum nome de campo aparece literal em script ({len(scripts)} verificado(s))"
        + (f" — {len(literais)} ocorrência(s)" if literais else ""),
    )
    for achado in literais:
        print(f"    {achado}")
    if literais:
        print(
            "\n  Nome de campo de prazo sai da política, em execução. Literal em\n"
            "  script transforma decisão de negócio em mudança de código — que é\n"
            "  o custo que faz a regra ficar errada por inércia (decisões 0003).",
        )

    # ─── A documentação não diverge ─────────────────────────────────────────

    doc = Path(opcoes.doc)
    esperado = tabela(dados)
    if opcoes.gerar:
        return gerar(doc, esperado)

    if not doc.is_file():
        afirmar(False, f"documentação ausente: {opcoes.doc}")
        return 1 if falhas else 0

    encontrado = bloco_do_doc(doc.read_text(encoding="utf-8"))
    afirmar(
        encontrado is not None,
        f"{caminho_relativo(doc)} tem o bloco gerado, entre os marcadores",
    )
    if encontrado is not None:
        afirmar(
            encontrado == esperado,
            f"a tabela de {caminho_relativo(doc)} é a que sai da política",
        )
        if encontrado != esperado:
            print("    a documentação diverge do .yaml. Regrave com:")
            print("      tests/prazo/verificar.py --gerar")

    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
