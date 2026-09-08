# Verificação de sanitização

Este repositório é público e deriva de conhecimento adquirido em trabalho
privado. O que se transporta é **engenharia**; o que não se transporta é
**qualquer identificador**. A fronteira está na
[`SPEC`](../../docs/SPEC.md) §9 e o raciocínio em
[`decisoes/0002`](../../docs/decisoes/0002-sanitizacao-verificada-por-teste.md).

`verificar.py` roda em `tests/casos/00-sanitizacao.sh` e no CI. Ele tem duas
metades, e a divisão resolve um problema de projeto real.

## O problema

Uma lista de termos proibidos em texto claro **anuncia a origem** — é a
informação que ela deveria proteger, publicada no repositório. Uma lista mantida
fora do repositório não roda no CI, e então não é garantia
([`decisoes/0002`](../../docs/decisoes/0002-sanitizacao-verificada-por-teste.md)
descarta hook local pela mesma razão).

## As duas metades

**`padroes.txt` — classes, em texto claro.** Expressão regular para o que se
reconhece pela *forma*: domínio de instância de SaaS, prefixo de token, id de
campo customizado, chave de issue de outro projeto, e-mail corporativo. É a
parte generalizável, e não há nada a esconder nela — ela descreve formatos
públicos.

**`tokens.sha256` — literais, como hash.** Um hash salgado por termo proibido.
O verificador quebra cada arquivo rastreado em tokens, aplica o mesmo hash e
compara. Pega o literal sem publicá-lo.

⚠️ **Isto é obfuscação, não sigilo.** O sal está neste repositório, e um ataque
de dicionário recupera termo curto em segundos. **O objetivo não é resistir a
ataque** — é não ter a lista em texto claro para quem simplesmente abre o
arquivo. Nada que seja credencial entra aqui: credencial não se protege por
`grep`, se rotaciona.

⚠️ **A falha reporta arquivo e linha, nunca o termo.** Log de CI de repositório
público é público, e um teste que imprime o que encontrou publica exatamente o
que a lista existe para não publicar. Quem escreveu o commit sabe qual é o
termo ao olhar a linha.

## Acrescentar um termo

```bash
tests/sanitizacao/hash.py "termo"   # imprime a linha a colar em tokens.sha256
```

Um termo é um **token**: sequência alfanumérica única, minúscula. `teo-whatsapp`
não é um termo — `teo` e `whatsapp` são, e basta um deles.

## Limites conhecidos

- **Só o literal e a forma.** Paráfrase que descreva um sistema interno com
  precisão suficiente para identificá-lo passa. Essa parte continua sendo
  julgamento, e é por isso que a SPEC §9 mantém a regra além do teste.
- **Token, não substring.** Termo grudado em outra palavra sem separador
  alfanumérico escapa da metade dos hashes — a metade dos padrões cobre os
  casos que importam (domínio, prefixo de token).
- **Falso positivo é possível**, e o conserto é ajustar o termo ou o padrão,
  nunca remover a verificação.
