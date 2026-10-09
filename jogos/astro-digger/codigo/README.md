# Astro Digger: código (protótipo)

Projeto **Godot 4.7** (renderizador *Compatibility*, o mais leve, roda em celular fraco).

## Como abrir e jogar
1. Baixe o Godot 4.7 em https://godotengine.org/download (a versão normal, não a .NET).
2. Abra o Godot → **Importar** → escolha `jogos/astro-digger/codigo/project.godot`.
3. Aperte **F5** (ou o botão ▶) pra jogar.

O botão **"Recomeçar (só no teste)"** aparece só nas versões de teste e apaga o progresso.

## O que já funciona
- **Minas e refinaria** com compra x1, x10 e MÁX
- **Marcos de nível** (x2 no nv 10, 25, 50...)
- **Botão MINERAR** (o toque vale 0,5 s de produção do planeta)
- **Nave** com 4 peças. Ao lançar, libera o próximo planeta e viaja até ele
- **Viagem livre** entre planetas liberados, com animação de ~1 s que não dá pra pular
- **Bônus de presença** (x2 no planeta onde você está), com todos os planetas produzindo
- **Ganho offline** (50%, até 4 h) e aviso "enquanto você estava fora..."
- **Save automático** a cada 10 s e quando o app vai pro segundo plano
- **Rebirth ("Nova Expedição")**: libera quando a nave de Marte fica pronta. Rende Poeira Estelar e pede confirmação em 2 toques pra ninguém resetar sem querer. O botão mostra **(!)** quando vale a pena
- **Árvore de habilidades**: 16 nós em 4 ramos, todos funcionando (produção, barras, naves mais baratas, offline, presença x3...)
- **Compra automática (AUTO)**: liberada pela árvore, usa a mesma estratégia do simulador
- **Mecânicas dos planetas** (painel "Especial" no topo de cada planeta):
  - Terra: **camadas** de profundidade com bônus e curiosidades reais
  - Lua: **fragmentos que quicam**. Toque pra ganhar barras de titânio
  - Marte: **tempestades de poeira** com aviso, tela avermelhada e botão de escudo

## O que ainda NÃO tem (próximas etapas)
- Arte final (por enquanto são caixas e um foguete simples)
- Missões, sequência de login, anúncios, compras
- **Security Foundation**: save criptografado, horário do servidor, Play Integrity. Os pontos do código que vão mudar estão marcados com `SECURITY FOUNDATION`

## Como o código está organizado
```
data/economia.json             TODOS os números do jogo (o simulador também lê daqui)
scripts/autoload/economia.gd   fórmulas: custo, produção, marcos, nave
scripts/autoload/jogo.gd       estado do jogador e ações (comprar, lançar, viajar, salvar)
scripts/ui/main.gd             tela principal (montada por código)
scripts/ui/painel_arvore.gd    painel Expedição: rebirth + árvore
scripts/ui/estilo.gd           cores e peças visuais comuns a todas as telas
scripts/mecanicas/             mecânicas dos planetas (camadas, fragmentos, tempestade)
scripts/viagens/               animações de viagem (cada skin futura é um arquivo aqui)
scripts/util/formatar.gd       números curtos: 1234567 -> 1,23M
tests/test_economia.gd         testes automáticos
```

## Testes automáticos
Conferem fórmulas, compras, nave, viagem, offline, save (inclusive save corrompido), árvore, rebirth, mecânicas dos planetas, se as telas abrem sem erro e se o ritmo da 1ª sessão continua batendo com o simulador. Também conferem que a 2ª expedição, com a árvore, fica bem mais rápida. Os testes nunca mexem no seu save de verdade.

```
godot --headless --path . -s res://tests/test_economia.gd
```

Resultado esperado: `TODOS OS TESTES PASSARAM`. Rode sempre depois de mexer no `economia.json`.

## Desempenho
- A tela atualiza 10x por segundo, não a cada quadro
- `low_processor_mode` ligado: o jogo só redesenha quando algo muda
- Planetas fora da tela são calculados por fórmula, sem gráficos
- Medido no PC de testes: ~0,4 ms de CPU por quadro
