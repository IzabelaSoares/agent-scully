# 0006 — O número esperado do radar mora na conferência à mão, não no caso

14/10/2026 · aceita

## Contexto

O radar de prazo ([`0003`](0003-politica-de-sla-declarativa.md),
[`0005`](0005-idade-nao-e-prazo-na-saida-do-radar.md)) devolve número que vai
virar linha de laudo: «nove dias de atraso», «dois sob controle». A task C3 de
[`TASKS.md`](../TASKS.md) exige que esse número seja conferido à mão e que **a
conferência fique registrada — não no histórico de conversa de ninguém**.

A exigência não é cerimônia. Número de laudo que ninguém conferiu é número em
que ninguém deveria acreditar, e conferir uma vez no terminal de quem escreveu o
coletor não resolve: a conta morre ali, o radar fica livre para mudar de resposta
depois, e ninguém refaz nada. O caso 08 já afirmava alguns desses números, mas
afirmá-los **dentro** do script deixa aberta a pergunta que importa: aquele `9`
foi conferido, ou foi copiado da saída do programa?

## Decisão

O esperado mora em `tests/fixtures/board/conferencia.md` — uma tabela escrita à
mão a partir da política e da amostra, com **a conta ao lado de cada número**
(`referência − data que valeu`) e o campo citado pela **posição na precedência**
(`cliente[1]`), nunca pelo nome. `tests/casos/09-conferencia.sh` tira dali o
esperado e compara com o radar.

O verificador refaz a subtração de cada linha por um caminho que não é o do radar
(`datetime`, não `jq`), busca na amostra a data que a linha diz ter usado, e exige
cobertura fechada: toda issue da amostra tem linha, e toda linha tem issue.

## Alternativas descartadas

- **Asserção com o número escrito no próprio caso**, como o caso 08 faz. É o que
  já existia, e continua existindo para o que ele prova (precedência, limiar que
  sai do arquivo, data injetável). Descartada **como registro da conferência**:
  um número solto num script não carrega a conta que o produziu, então ninguém
  que revisa consegue distinguir conferência de transcrição — e é justamente essa
  distinção que a C3 pede.
- **Golden file gerado pelo próprio radar** (`--gerar`, como a tabela de
  `.ai/docs/prazo.md`). Descartada: golden gerado pelo programa sob teste detecta
  **mudança**, e nunca **erro**. Ele congela o que o radar faz hoje, inclusive se
  o que ele faz hoje estiver errado — e a C3 pede o contrário disso. A geração
  continua certa onde a fonte é outra: lá quem gera a tabela é a política, que não
  é o programa sob teste.
- **A conferência só no corpo do PR.** Descartada: corpo de PR não roda. Ele
  envelhece sem avisar, e a mudança seguinte no radar não precisa encostar nele —
  que é a definição do registro que a C3 recusa.
- **Reimplementar a classificação em Python dentro do teste e comparar.**
  Descartada pela mesma razão que a política tem um leitor só: duas implementações
  da mesma regra divergem, e a divergência aparece como teste verde sobre
  comportamento errado. O teste compara o radar com uma conta **humana**, não com
  um segundo radar.

## Consequências

- **O dia em que o radar mudar de resposta é um diff.** Ou a conferência muda
  junto — e a conta nova aparece ao lado da antiga, para quem revisa —, ou o caso
  cai. É a mesma regra do golden file do [`CONTRIBUTING.md`](../../CONTRIBUTING.md),
  com a diferença de que aqui o diff mostra a conta, e não só o resultado.
- **Amostra que cresce custa conferência.** Issue nova sem linha derruba o caso,
  de propósito: amostra que cresce sem ninguém conferir o que cresceu é amostra
  que dá confiança sem dar garantia. O custo é real e foi aceito.
- **Consequência ruim, e assumida:** a conferência é humana, logo pode estar
  errada. Duas redes limitam o estrago — a conta é refeita por um caminho
  independente, e as datas têm de estar na amostra —, mas nenhuma das duas julga
  a *classificação*: se a pessoa que conferiu e o radar estiverem errados do mesmo
  jeito, a suíte fica verde. O que o arquivo entrega contra isso não é automação:
  é a razão de cada linha escrita por extenso, que é o que um revisor consegue
  contestar.
- Os quatro dublês de `tests/fixtures/board/conferencia-dubles/` existem porque
  teste de negação que nunca falhou não prova nada — inclusive o que prova que a
  comparação com o radar sabe falhar.

## Como se revisita

Quando a amostra passar do que uma pessoa confere à mão numa sentada — algo como
algumas dezenas de issues —, a tabela deixa de ser mantível e vira ritual. A saída
não é abandonar a conferência: é separar uma **amostra núcleo**, pequena e
conferida célula a célula, de uma amostra maior verificada só por invariante
(ninguém some, 🔴 nunca sai da idade, a soma fecha). A evidência que reabre a
discussão é concreta: o primeiro PR em que a conferência for atualizada sem que
ninguém refaça a conta.
