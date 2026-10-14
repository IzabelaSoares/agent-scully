#!/usr/bin/env python3
"""O radar reproduz o número conferido à mão (TASKS C3).

A conferência mora em `tests/fixtures/board/conferencia.md`, escrita célula a
célula a partir da política e da amostra, **antes** de rodar o radar. Este
verificador é o que a torna uma rede em vez de um documento: ele refaz a conta
da conferência, confere que ela descreve mesmo a amostra, e só então compara o
radar com ela.

Quatro verificações, e cada uma fecha um buraco diferente:

  1. **A conta da conferência fecha sozinha.** Cada linha declara a subtração
     que fez (`referência − data que valeu`) e o número que saiu dela; aqui a
     subtração é refeita com `datetime`, que não é o caminho do radar. Número
     escrito errado na tabela viraria «esperado» errado — e um esperado errado
     que o radar reproduz é o pior resultado possível: verde, e mentindo.
  2. **A conferência descreve a amostra, e não um board imaginário.** A data que
     a linha diz ter usado é buscada na amostra, no campo que a linha diz ter
     valido. Sem isto, a tabela poderia conferir sete issues que não existem e
     continuar passando.
  3. **A cobertura é fechada.** Toda issue da amostra tem uma linha, e toda
     linha tem uma issue. Issue nova na amostra sem linha na conferência derruba
     o caso — que é o que impede a amostra de crescer sem ninguém conferir o que
     cresceu.
  4. **O radar reproduz a conferência**, item a item e agregado a agregado,
     sobre a mesma amostra e a mesma data de referência.

⚠️ **Nenhum nome de campo de prazo aparece aqui.** A conferência cita o campo
pela posição na precedência (`cliente[1]`), e o nome é resolvido da política em
execução — mesma regra que `tests/prazo/verificar.py` impõe a todo script
(decisões 0003).

Uso:
  tests/conferencia/verificar.py                      (a partir da raiz)
  tests/conferencia/verificar.py --conferencia ARQUIVO

Status 0 se tudo passa; 1 se alguma verificação falha.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent

# O leitor da política é o do radar — um só. Dois leitores deixariam este
# verificador resolver `cliente[1]` para um campo diferente do que o radar usou.
sys.path.insert(0, str(RAIZ / ".ai" / "tools" / "lib"))
from politica import ErroDePolitica, Valor, ler_politica  # noqa: E402

MARCADOR_REFERENCIA = re.compile(r"<!--\s*referencia:\s*(\d{4}-\d{2}-\d{2})\s*-->")
CABECALHO_ITENS = ("Chave", "Origem aplicada", "Base", "Campo que valeu", "Conta",
                   "Número", "Classificação")
CABECALHO_AGREGADOS = ("Agregado", "Conferido à mão")
POSICIONAL = re.compile(r"^`?([a-z_]+)\[(\d+)\]`?$")
# A conferência escreve o sinal de menos tipográfico; aceitar o hífen também é
# cortesia com quem editar a tabela num editor que não o tenha.
SUBTRACAO = re.compile(r"\s+[−-]\s+")
AGREGADOS_EXIGIDOS = ("total", "examinados", "truncado", "sob_controle", "itens")

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


def texto(valor: object) -> str:
    return valor.texto if isinstance(valor, Valor) else ""


def limpar(celula: str) -> str:
    return celula.strip().strip("`").strip()


def tabela(conteudo: str, cabecalho: tuple[str, ...]) -> list[dict[str, str]]:
    """As linhas da tabela cujo cabeçalho casa, na ordem em que aparecem."""
    linhas = conteudo.splitlines()
    for numero, linha in enumerate(linhas):
        if not linha.lstrip().startswith("|"):
            continue
        colunas = [celula.strip() for celula in linha.strip().strip("|").split("|")]
        if tuple(colunas) != cabecalho:
            continue
        encontradas = []
        for seguinte in linhas[numero + 2 :]:  # +2 pula a linha de separação
            if not seguinte.lstrip().startswith("|"):
                break
            celulas = [celula.strip() for celula in seguinte.strip().strip("|").split("|")]
            if len(celulas) != len(cabecalho):
                continue
            encontradas.append(dict(zip(cabecalho, celulas)))
        return encontradas
    return []


def inteiro(celula: str) -> int | None:
    bruto = limpar(celula).replace("−", "-")
    try:
        return int(bruto)
    except ValueError:
        return None


def dia(texto_da_data: str) -> date | None:
    try:
        return date.fromisoformat(texto_da_data.strip())
    except ValueError:
        return None


def campo_resolvido(posicional: str, politica: dict) -> str | None:
    """`cliente[1]` → o nome do 1º campo da precedência de `cliente`, da política."""
    casou = POSICIONAL.match(posicional.strip())
    if not casou:
        return None
    origem, posicao = casou.group(1), int(casou.group(2))
    campos = ((politica.get("origens") or {}).get(origem) or {}).get("campos") or []
    if posicao < 1 or posicao > len(campos):
        return None
    return texto(campos[posicao - 1])


def valor_na_amostra(issue: dict, nome_do_campo: str, id_de: dict) -> str | None:
    identificador = id_de.get(nome_do_campo)
    if identificador is None:
        return None
    bruto = (issue.get("fields") or {}).get(identificador)
    if isinstance(bruto, dict):
        bruto = bruto.get("value")
    if not isinstance(bruto, str) or not bruto.strip():
        return None
    return bruto[:10]


def rodar_radar(radar: Path, amostra: Path, referencia: str) -> dict | None:
    ambiente = dict(os.environ, SCULLY_AGORA=referencia, SCULLY_SEM_ENV="1")
    execucao = subprocess.run(
        ["bash", str(radar), "--amostra", str(amostra)],
        capture_output=True,
        text=True,
        env=ambiente,
    )
    if execucao.returncode != 0 or not execucao.stdout.strip():
        print(f"    o radar saiu {execucao.returncode}: {execucao.stderr.strip()}")
        return None
    try:
        return json.loads(execucao.stdout)
    except json.JSONDecodeError:
        return None


def main() -> int:
    argumentos = argparse.ArgumentParser(add_help=True)
    argumentos.add_argument(
        "--conferencia", default=str(RAIZ / "tests/fixtures/board/conferencia.md")
    )
    argumentos.add_argument(
        "--amostra", default=str(RAIZ / "tests/fixtures/board/amostra.json")
    )
    argumentos.add_argument(
        "--radar", default=str(RAIZ / ".ai/tools/coleta/board-radar.sh")
    )
    argumentos.add_argument(
        "--politica", default=str(RAIZ / ".ai/politicas/prazo.yaml")
    )
    opcoes = argumentos.parse_args()

    conferencia = Path(opcoes.conferencia)
    if not conferencia.is_file():
        print(f"✗ conferência ausente: {opcoes.conferencia}")
        return 1
    conteudo = conferencia.read_text(encoding="utf-8")

    try:
        politica, _ = ler_politica(Path(opcoes.politica))
    except ErroDePolitica as erro:
        print(f"✗ política ilegível — {erro}")
        return 1

    carga = json.loads(Path(opcoes.amostra).read_text(encoding="utf-8"))
    id_de = {nome: ident for ident, nome in (carga.get("names") or {}).items()}
    issues = {issue["key"]: issue for issue in carga.get("issues") or []}

    # ─── A conferência é legível ────────────────────────────────────────────

    casou = MARCADOR_REFERENCIA.search(conteudo)
    afirmar(casou is not None, "a conferência declara a data de referência que valeu")
    if casou is None:
        print("    sem ela a tabela valeria por um dia só, e envelheceria em silêncio")
        return 1
    referencia = casou.group(1)
    hoje = dia(referencia)

    linhas = tabela(conteudo, CABECALHO_ITENS)
    agregados = {
        limpar(linha["Agregado"]): linha["Conferido à mão"].strip()
        for linha in tabela(conteudo, CABECALHO_AGREGADOS)
    }
    afirmar(bool(linhas), f"a conferência traz a tabela issue a issue ({len(linhas)} linha(s))")
    faltando = [chave for chave in AGREGADOS_EXIGIDOS if chave not in agregados]
    afirmar(
        not faltando,
        "a conferência traz a tabela dos agregados"
        + (f" — falta: {', '.join(faltando)}" if faltando else ""),
    )
    if not linhas or faltando or hoje is None:
        return 1

    # ─── A cobertura é fechada ──────────────────────────────────────────────

    conferidas = [limpar(linha["Chave"]) for linha in linhas]
    afirmar(
        len(conferidas) == len(set(conferidas)),
        "nenhuma issue é conferida duas vezes",
    )
    sem_linha = sorted(set(issues) - set(conferidas))
    sem_issue = sorted(set(conferidas) - set(issues))
    afirmar(
        not sem_linha and not sem_issue,
        f"toda issue da amostra tem linha, e vice-versa ({len(issues)} issue(s))"
        + (f" — sem linha: {', '.join(sem_linha)}" if sem_linha else "")
        + (f" — sem issue: {', '.join(sem_issue)}" if sem_issue else ""),
    )

    # ─── A conta de cada linha fecha, e sobre a amostra ─────────────────────

    esperado: dict[str, dict] = {}
    for linha in linhas:
        chave = limpar(linha["Chave"])
        base = limpar(linha["Base"])
        partes = SUBTRACAO.split(linha["Conta"].strip())
        minuendo = dia(partes[0]) if len(partes) == 2 else None
        subtraendo = dia(partes[1]) if len(partes) == 2 else None
        numero = inteiro(linha["Número"])
        posicional = limpar(linha["Campo que valeu"])
        campo = None if base == "idade" else campo_resolvido(posicional, politica)

        if minuendo is None or subtraendo is None or numero is None:
            afirmar(False, f"{chave}: a linha declara a conta e o número que saiu dela")
            continue
        if base not in ("prazo", "idade"):
            afirmar(False, f"{chave}: a base é `prazo` ou `idade` — veio `{base}`")
            continue
        if base == "prazo" and campo is None:
            afirmar(False, f"{chave}: `{posicional}` não é posição de campo da política")
            continue

        # 1. A subtração, refeita por um caminho que não é o do radar.
        afirmar(
            minuendo == hoje and (minuendo - subtraendo).days == numero,
            f"{chave}: a conta da conferência fecha ({numero} dia(s), da referência)",
        )

        # 2. A data que a linha diz ter usado está mesmo na amostra, no campo que
        #    a linha diz ter valido.
        issue = issues.get(chave)
        if issue is None:
            continue
        if base == "prazo":
            na_amostra = valor_na_amostra(issue, campo, id_de)
            onde = f"no {posicional}"
        else:
            bruto = (issue.get("fields") or {}).get("created")
            na_amostra = bruto[:10] if isinstance(bruto, str) else None
            onde = "na data de criação"
        afirmar(
            na_amostra == subtraendo.isoformat(),
            f"{chave}: a data da conta é a que está na amostra, {onde}",
        )

        esperado[chave] = {
            "base": base,
            "campo_do_prazo": campo,
            "prazo_efetivo": subtraendo.isoformat() if base == "prazo" else None,
            "dias_de_atraso": numero if base == "prazo" else None,
            "dias_de_idade": numero if base == "idade" else None,
            "classificacao": limpar(linha["Classificação"]),
        }

    if len(esperado) != len(linhas):
        print("\n  A conferência não fecha consigo mesma — o radar nem foi chamado.")
        return 1

    # ─── O radar reproduz a conferência ─────────────────────────────────────

    saida = rodar_radar(Path(opcoes.radar), Path(opcoes.amostra), referencia)
    afirmar(saida is not None, "o radar devolve JSON sobre a mesma amostra")
    if saida is None:
        return 1

    afirmar(
        saida.get("referencia") == referencia,
        "o radar julgou na data de referência da conferência",
    )

    do_radar = {item["chave"]: item for item in saida.get("itens") or []}
    for chave, campos in esperado.items():
        if campos["classificacao"] == "🟢":
            # 🟢 é contado e não listado: a ausência na lista é o esperado, e a
            # contagem é conferida logo abaixo.
            afirmar(chave not in do_radar, f"{chave}: 🟢 é contado, e não listado")
            continue
        obtido = do_radar.get(chave)
        if obtido is None:
            afirmar(False, f"{chave}: a conferência o espera na lista, e o radar não o lista")
            continue
        divergentes = {
            nome: (valor, obtido.get(nome))
            for nome, valor in campos.items()
            if obtido.get(nome) != valor
        }
        afirmar(not divergentes, f"{chave}: o radar reproduz a linha conferida à mão")
        for nome, (conferido, veio) in divergentes.items():
            print(f"    {nome}: conferido à mão {conferido!r}, radar {veio!r}")

    inesperados = sorted(set(do_radar) - {c for c, v in esperado.items() if v["classificacao"] != "🟢"})
    afirmar(
        not inesperados,
        "o radar não lista nada que a conferência não espere"
        + (f" — {', '.join(inesperados)}" if inesperados else ""),
    )

    # ─── Os agregados ───────────────────────────────────────────────────────

    for chave in ("total", "examinados", "sob_controle"):
        conferido = inteiro(agregados[chave])
        afirmar(
            conferido is not None and saida.get(chave) == conferido,
            f"`{chave}`: o radar reproduz o {agregados[chave]} conferido à mão"
            + ("" if conferido is None else f" (veio {saida.get(chave)})"),
        )

    afirmar(
        str(saida.get("truncado")).lower() == limpar(agregados["truncado"]).lower(),
        f"`truncado`: o radar reproduz o `{limpar(agregados['truncado'])}` conferido à mão",
    )

    ordem_conferida = [limpar(parte) for parte in agregados["itens"].split("·")]
    ordem_do_radar = [item["chave"] for item in saida.get("itens") or []]
    afirmar(
        ordem_conferida == ordem_do_radar,
        "a ordem dos itens é a conferida à mão: 🔴 antes de 🟡, e quem espera há mais tempo na frente",
    )
    if ordem_conferida != ordem_do_radar:
        print(f"    conferido à mão: {' · '.join(ordem_conferida)}")
        print(f"    radar:           {' · '.join(ordem_do_radar)}")

    # Fecha a conta que a conferência faz no fim: ninguém sumiu pelo caminho.
    afirmar(
        saida.get("sob_controle", 0) + len(ordem_do_radar) == saida.get("examinados"),
        "listados mais sob controle dão o total examinado — nenhum bug sumiu pelo caminho",
    )

    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
