# Issue left unchecked

> **Dublê quebrado de propósito** (`tests/casos/09-conferencia.sh`).
> Teste de negação que nunca falhou não prova nada: este arquivo é a
> conferência boa com **um** defeito, e o caso falha se ele passar.

MRD-107 sumiu da tabela. É o modo de falha da amostra que cresce sem ninguém
conferir o que cresceu — e o que cai de fora é justamente a issue de rótulo
desconhecido, que é a que mais precisa de conferência.

<!-- referencia: 2026-09-14 -->

| Chave | Origem aplicada | Base | Campo que valeu | Conta | Número | Classificação |
|---|---|---|---|---|---|---|
| MRD-101 | `cliente`, pelo rótulo | prazo | `cliente[1]` | 2026-09-14 − 2026-09-05 | 9 | 🔴 |
| MRD-102 | `interno`, pelo rótulo | prazo | `interno[1]` | 2026-09-14 − 2026-09-16 | -2 | 🟡 |
| MRD-103 | `cliente`, pelo padrão | prazo | `cliente[2]` | 2026-09-14 − 2026-09-14 | 0 | 🟡 |
| MRD-104 | `cliente`, pelo rótulo | idade | — | 2026-09-14 − 2026-08-01 | 44 | 🟡 |
| MRD-105 | `interno`, pelo rótulo | prazo | `interno[2]` | 2026-09-14 − 2026-10-30 | -46 | 🟢 |
| MRD-106 | `cliente`, pelo rótulo | idade | — | 2026-09-14 − 2026-09-10 | 4 | 🟢 |

| Agregado | Conferido à mão |
|---|---|
| `total` | 7 |
| `examinados` | 7 |
| `truncado` | false |
| `sob_controle` | 2 |
| `itens` | MRD-101 · MRD-104 · MRD-103 · MRD-102 |
