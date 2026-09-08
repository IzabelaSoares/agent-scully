## O que muda

<!-- Uma ou duas frases. O diff diz o quê; aqui vai o por quê. -->

## Evidência

<!--
Como você sabe que funciona. Saída de comando, print do laudo, número conferido
à mão. "Testei localmente" não é evidência — é afirmação.
-->

## Verificações

- [ ] `tests/run.sh` passa, com `shellcheck` instalado
- [ ] Limiar novo foi para `.ai/politicas/`, com a razão ao lado, e não literal em script
- [ ] Armadilha nova foi para a SPEC §10, com data e evidência
- [ ] Golden file mudou? O diff está no commit e a mudança é deliberada
- [ ] Mudou a forma do sistema? Há entrada em `docs/decisoes/`, com as alternativas descartadas
- [ ] Nenhum identificador de empresa, cliente ou instância de terceiro (o CI verifica)

## Etapa

<!-- Qual etapa do docs/PLAN.md e qual task do docs/TASKS.md este PR fecha. -->
