# Date that is not in the sample

> **Dublê quebrado de propósito** (`tests/casos/09-conferencia.sh`).
> Teste de negação que nunca falhou não prova nada: este arquivo é a
> conferência boa com **um** defeito, e o caso falha se ele passar.

A conta de MRD-101 fecha sozinha (14 − 4 = 10), e a data usada **não está na
amostra**. Conferência que confere issue imaginária passaria por aritmética e
não provaria nada sobre o board.

<!-- referencia: 2026-09-14 -->

| Chave | Origem aplicada | Base | Campo que valeu | Conta | Número | Classificação |
|---|---|---|---|---|---|---|
| MRD-101 | `cliente`, pelo rótulo | prazo | `cliente[1]` | 2026-09-14 − 2026-09-04 | 10 | 🔴 |
| MRD-102 | `interno`, pelo rótulo | prazo | `interno[1]` | 2026-09-14 − 2026-09-16 | -2 | 🟡 |
| MRD-103 | `cliente`, pelo padrão | prazo | `cliente[2]` | 2026-09-14 − 2026-09-14 | 0 | 🟡 |
| MRD-104 | `cliente`, pelo rótulo | idade | — | 2026-09-14 − 2026-08-01 | 44 | 🟡 |
| MRD-105 | `interno`, pelo rótulo | prazo | `interno[2]` | 2026-09-14 − 2026-10-30 | -46 | 🟢 |
| MRD-106 | `cliente`, pelo rótulo | idade | — | 2026-09-14 − 2026-09-10 | 4 | 🟢 |
| MRD-107 | `cliente`, pelo padrão | prazo | `cliente[2]` | 2026-09-14 − 2026-09-01 | 13 | 🔴 |

| Agregado | Conferido à mão |
|---|---|
| `total` | 7 |
| `examinados` | 7 |
| `truncado` | false |
| `sob_controle` | 2 |
| `itens` | MRD-107 · MRD-101 · MRD-104 · MRD-103 · MRD-102 |
