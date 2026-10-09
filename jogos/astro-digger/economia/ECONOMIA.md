# Economia — Astro Digger (MVP)

> Todos os números ficam em [`codigo/data/economia.json`](../codigo/data/economia.json), dentro do projeto do jogo. O jogo e o simulador leem esse mesmo arquivo, então **pra balancear não precisa mexer em código**: muda o número, roda o simulador e confere.

## 1. Moedas

| Moeda | Pra que serve | Onde vive |
|-------|---------------|-----------|
| 💰 **Créditos** | Comprar melhorias (minas e refinarias). Valem em todos os planetas. | No celular, conferido pelo servidor |
| 🧱 **Barras** (uma por planeta: Ferro, Titânio, Hematita) | Construir naves | No celular, conferido pelo servidor |
| ✨ **Poeira Estelar** | Árvore de habilidades (ganha no rebirth) | No celular, conferido pelo servidor |
| 💎 **Cristais** | Premium: skins e salto no tempo | **Só no servidor** |

## 2. Como cada planeta funciona

Cada planeta tem:
- **8 minas** que produzem Créditos por segundo. Cada uma só libera depois da anterior.
  - Cada mina produz **3x** a anterior e custa **6,5x** mais, então as últimas viram metas de longo prazo.
  - Elas também ficam um pouco mais caras por nível (crescimento de 15% na 1ª até 18,5% na 8ª).
  - Ritmo medido no simulador: na Terra, 6 minas saem nos primeiros 9 min (uma nova a cada ~1,5 min). As 2 últimas ficam pra depois. Em Marte, a 8ª mina aparece por volta do dia 3.
- **1 refinaria** que produz Barras por segundo.
- **1 nave** com 4 partes, construída com Barras.

### Fórmulas (explicadas)
- **Produção da mina** = produção base × nível × bônus de marcos
- **Bônus de marcos:** ao chegar nos níveis 10, 25, 50, 100, 150, 200, 300, 400 e 500, a produção **dobra**. É o "pulo" que deixa idle viciante.
- **Custo do próximo nível** = custo base × crescimento^nível (cada nível fica de 15% a 20% mais caro)
- **Refinaria:** mesma lógica, mas gera Barras

### Os 3 planetas do MVP
| Planeta | Escala de produção | Nave pede |
|---------|-------------------|-----------|
| Terra | unidades → milhares | 12 mil Barras de Ferro |
| Lua | milhares → milhões | 40 mil Titânio + **60 mil Ferro** (da Terra) |
| Marte | milhões → trilhões | 500 mil Hematita + **800 mil Titânio** (da Lua). No MVP, concluir a nave libera o rebirth; na atualização, leva ao Cinturão de Asteroides |

**Dependência:** a nave de cada planeta pede Barras do planeta anterior. Por isso vale a pena continuar melhorando a refinaria da Terra mesmo estando na Lua.

## 3. Presença, colônias e offline

| Situação | Produção |
|----------|----------|
| Planeta onde você está | **×2** (bônus de presença) + toque na tela |
| Outros planetas desbloqueados | ×1 (automático) |
| Offline (app fechado) | **50%**, acumulando até **4 horas** |

A árvore de habilidades aumenta o limite offline até 12 h e a eficiência até 100%. O limite existe por dois motivos: incentivar a volta ao jogo e conter a trapaça de adiantar o relógio.

## 4. Rebirth: "Nova Expedição"

- **Libera:** ao construir a nave de Marte (por volta do dia 4 ou 5 pro jogador típico).
  - Por que não antes? O simulador mostrou que um rebirth antes disso **atrasa** o jogador (ele perde mais do que ganha). Liberar só quando vale a pena evita essa armadilha.
- **O que reseta:** Créditos, Barras, minas, refinarias e planetas (você volta pra Terra).
- **O que fica:** Poeira Estelar, árvore de habilidades, Cristais, skins e animações de viagem.
- **Fórmula:** `Poeira = (créditos ganhos na expedição ÷ 100 bilhões) ^ (1/3)`, arredondado pra baixo.
  - A raiz cúbica faz cada rebirth render mais que o anterior, mas sem explodir.

## 5. Árvore de habilidades (MVP: 16 nós em 4 ramos)

Cada ramo tem 4 nós. Pra liberar um nó, precisa ter pelo menos 1 ponto no nó anterior do mesmo ramo.

| Ramo | Nós (em ordem) |
|------|----------------|
| ⛏️ Mineração | **Brocas Afiadas** (+25% produção/nível, até 10) → **Toque Pesado** (toque ×2) → **Veio Rico** (1ª mina de cada planeta ×2) → **Marcos Turbinados** (marcos dão ×2,5 em vez de ×2) |
| 🤖 Automação | **Refino Rápido** (+20% Barras/nível, até 10) → **Gerente Inicial** (começa com a 1ª mina da Terra no nível 10) → **Compra Automática** → **Drones de Colônia** (planetas fora de presença rendem +50%) |
| 🚀 Engenharia | **Projeto Enxuto** (−5% Barras nas naves/nível, até −30%) → **Capital Inicial** (+1.000 Créditos no início) → **Plataforma Pronta** (casco da nave da Terra já vem pronto) → **Refinaria Orbital** (refinarias 25% mais baratas) |
| 🌙 Exploração | **Cofre Offline** (+1 h de limite/nível, até 8) → **Turno da Noite** (+10% eficiência offline/nível, até 100%) → **Faro de Explorador** (+10% Poeira/nível) → **Presença Forte** (presença ×3) |

**Custo:** os nós de vários níveis custam 1, 2, 3... Poeira (cada nível custa 1 a mais). Os nós de nível único têm preço fixo.
Com cerca de 10 Poeira (o primeiro rebirth), o jogador fica em média **2× mais forte**.
No jogo de verdade (teste automático do Godot): gastando 10 Poeira em Brocas Afiadas, Refino Rápido e Projeto Enxuto, a chegada em Marte cai de **31 min pra 19 min**.

> O simulador em Python usa uma aproximação da árvore (+10% por Poeira). As regras exatas de cada nó estão no jogo (`codigo/scripts/autoload/jogo.gd`) e são conferidas pelos testes.

## 6. Ritmo do jogo

### A regra
- **1ª sessão (a mais longa, ~35 min):** Terra → Lua → Marte. O jogador vê **dois lançamentos de nave** logo na primeira vez que joga.
- **Depois disso, cada planeta demora mais que o anterior**, sem passar de uma semana:

| Viagem | Tempo-alvo (jogador típico, 1ª expedição) |
|--------|-------------------------------------------|
| Terra → Lua | 8 a 10 min |
| Lua → Marte | ~20 min (Marte com ~30 min de jogo) |
| Marte → Cinturão de Asteroides | 3 a 4 dias |
| Cada planeta seguinte | +1 dia em relação ao anterior |
| Teto | 7 dias por planeta (os rebirths deixam mais curto) |

Isso também está em `economia.json` → `ritmo_alvo`, pra servir de guia quando criarmos planetas novos.

### O que o simulador mediu
**Jogador contínuo** (sempre online): Lua em **9 min**, Marte em **32 min**, nave de Marte em 17 h.

**Jogador típico** (1ª sessão de 35 min, depois 5 sessões de 8 min por dia):
| Marco | Quando |
|-------|--------|
| Chega na Lua | 1ª sessão, ~9 min |
| Chega em Marte | 1ª sessão, ~32 min |
| Nave de Marte pronta (libera rebirth) | dia 4 a 5 |

**Jogador típico fazendo rebirth** (cada volta mais rápida):
| Expedição | Nave de Marte em | Poeira ganha |
|-----------|------------------|--------------|
| 1ª | 3,9 dias | +10 |
| 2ª | 2,5 dias | +11 |
| 3ª | 1,6 dia | +23 |
| 4ª | 1,2 dia | +46 |
| 5ª | 18 h | +92 |

Quando a volta começa a ficar curta demais (por volta da 2ª ou 3ª semana), é a hora certa de lançar o **Cinturão de Asteroides**, a primeira atualização de planeta.

> Pra rodar: `python simulador.py` (ou `python simulador.py --bonus 2` pra simular com bônus).
> O simulador é uma estimativa. Depois do lançamento, compare com os dados reais (Firebase Analytics) e ajuste.

### Ganchos pra pessoa voltar (sem punir quem some)
| Gancho | Como funciona |
|--------|---------------|
| 🚀 Peças da nave | A nave de Marte tem 4 peças, mais ou menos **uma por dia**. Sempre existe uma meta pro dia seguinte |
| 📦 Baú offline | Ao voltar: "enquanto você estava fora, suas minas renderam X". Um anúncio opcional dobra o valor |
| 📋 Missões diárias | 3 por dia, 5 Cristais cada |
| 📅 Sequência de 7 dias | Cristais e boosts. No 7º dia vem a **animação de viagem "Primeira Semana"** (exclusiva). Perder um dia **pausa** a sequência, sem zerar |
| 🏆 Nave de Marte concluída | 100 Cristais + animação **"Pioneiro"**, e libera o rebirth |
| 🔔 Notificações | Opcionais, no máximo 2 por dia: "cofre offline cheio" e "peça da nave pronta" |
| ⭐ Marcos de nível | Sempre tem um "×2" perto de chegar (nível 25, 50, 100...) |

## 7. Anúncios recompensados (sempre opcionais)
- **Produção ×2 por 30 min** por anúncio, acumulando até 4 h
- **Dobrar ganho offline** ao voltar pro jogo
- Limite: 10 anúncios por dia
- Nunca há anúncio forçado

## 8. Cristais (premium)
| Ganho grátis | Cristais |
|--------------|----------|
| Missão diária | 5 |
| Conquistas | 10 a 25 |
| Chegar num planeta novo | 50 |

| Uso | Cristais |
|-----|----------|
| Salto no tempo (2 h de produção na hora) | 40 |
| Skin comum | 150 |
| Skin rara | 400 |

Dá pra conseguir tudo jogando, e pagar só acelera. Os preços em reais ficam com o agente de Marketing.

## 9. Pro servidor (anti-trapaça)
O servidor conhece os níveis de cada mina (pelo save sincronizado), então ele consegue calcular o **máximo possível** de ganho num intervalo:

```
ganho_maximo = Σ (produção máxima de cada planeta × presença máxima × boosts ativos) × tempo_do_servidor_entre_syncs
```

Se o ganho reportado passar de `ganho_maximo × 1,5`, a conta é **sinalizada pra revisão**, sem ban automático. Assim ninguém leva punição injusta por bug.

## 10. Como adicionar um planeta novo (atualizações)
1. Copie o bloco de um planeta em `economia.json`.
2. Multiplique a escala (produção e custos) por algo entre 1.000 e 2.000 em relação ao anterior.
3. A nave do planeta anterior passa a apontar pro novo (`destino`).
4. A nave do novo planeta pede Barras dele e do anterior.
5. Rode o simulador e confira se o tempo até o planeta novo fica entre 2 e 5 dias pro jogador típico.
