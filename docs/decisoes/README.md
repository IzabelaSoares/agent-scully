# Decisões

Registro de **análise**, não de implementação. Existe para que a próxima pessoa
— inclusive a autora em três meses — não refaça o caminho, e em particular para
que **não reproponha o que foi considerado e descartado, com o motivo do
descarte junto**.

Uma decisão entra aqui quando muda a forma do sistema e não é óbvia a partir do
código. Ajuste de limiar não entra: é calibragem ([`../SPEC.md`](../SPEC.md)
§9.1) e vive em `.ai/politicas/`, com a razão ao lado do valor.

## Formato

Cinco seções, nesta ordem, e nenhuma opcional:

1. **Contexto** — o que era verdade quando a decisão foi tomada
2. **Decisão** — o que foi escolhido, em uma frase
3. **Alternativas descartadas** — cada uma com o motivo do descarte
4. **Consequências** — incluindo as ruins
5. **Como se revisita** — que evidência nova reabriria a discussão

A seção 5 é a que impede que um registro de decisão vire dogma. Decisão sem
critério de revisão é preferência com carimbo.

## Índice

| # | Decisão |
|---|---|
| [0001](0001-restricao-na-camada-mais-forte.md) | A restrição vai na camada mais forte que a suporta |
| [0002](0002-sanitizacao-verificada-por-teste.md) | Sanitização é verificada por teste, não por revisão |
| [0003](0003-politica-de-sla-declarativa.md) | A política de prazo é dado declarativo, não código |
| [0004](0004-metrica-de-processo-nao-e-meta.md) | Métrica de processo é instrumento, nunca meta |
