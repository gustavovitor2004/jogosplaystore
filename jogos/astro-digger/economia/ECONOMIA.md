# Economia — Astro Digger (MVP)

> Todos os números ficam em [`economia.json`](economia.json). O jogo lê esse arquivo, então **pra balancear não precisa mexer em código**: muda o número, roda o simulador e confere.

## 1. Moedas

| Moeda | Pra que serve | Onde vive |
|-------|---------------|-----------|
| 💰 **Créditos** | Comprar melhorias (minas e refinarias). Valem em todos os planetas. | No celular, conferido pelo servidor |
| 🧱 **Barras** (uma por planeta: Ferro, Titânio, Hematita) | Construir naves | No celular, conferido pelo servidor |
| ✨ **Poeira Estelar** | Árvore de habilidades (ganha no rebirth) | No celular, conferido pelo servidor |
| 💎 **Cristais** | Premium: skins e salto no tempo | **Só no servidor** |

## 2. Como cada planeta funciona

Cada planeta tem:
- **3 minas** que produzem Créditos por segundo. A segunda e a terceira mina destravam em sequência.
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
| Lua | milhares → milhões | 600 mil Titânio + **900 mil Ferro** (da Terra) |
| Marte | milhões → trilhões | 20 mi Hematita + **30 mi Titânio** (da Lua). Meta de longo prazo, libera o próximo planeta numa atualização |

**Dependência:** a nave de cada planeta pede Barras do planeta anterior. Por isso vale a pena continuar melhorando a refinaria da Terra mesmo estando na Lua.

## 3. Presença, colônias e offline

| Situação | Produção |
|----------|----------|
| Planeta onde você está | **×2** (bônus de presença) + toque na tela |
| Outros planetas desbloqueados | ×1 (automático) |
| Offline (app fechado) | **50%**, acumulando até **4 horas** |

A árvore de habilidades aumenta o limite offline até 12 h e a eficiência até 100%. O limite existe por dois motivos: incentivar a volta ao jogo e conter a trapaça de adiantar o relógio.

## 4. Rebirth: "Nova Expedição"

- **Libera:** ao chegar em Marte.
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

## 6. Ritmo do jogo (resultado do simulador)

**Jogador típico** (5 sessões de 8 minutos por dia):
| Marco | 1ª expedição | 2ª expedição (com árvore ≈ 2×) |
|-------|--------------|-------------------------------|
| Chega na Lua | dia 1, ~9 min de tela (1ª sessão) | ~4 min de tela |
| Chega em Marte | dia 3 (~1 h de tela) | dia 2 (~40 min de tela) |
| Rebirth recomendado | dia 5 a 6 (~9 a 12 Poeira) | dia 5 a 6 (~17 a 21 Poeira) |

**Jogador contínuo** (sempre online): Lua em 9 min e Marte em 4,6 h.

O ritmo segue o padrão que funciona em idle: **começo rápido** (o jogador já viaja de planeta na primeira sessão), meio mais calmo, e cada rebirth deixando o anterior mais rápido. Estimativa da equipe (o simulador só mede até o 2º rebirth): o MVP deve render umas **3 a 4 semanas** de conteúdo até a primeira atualização de planeta.

> Pra rodar: `python simulador.py` (ou `python simulador.py --bonus 2` pra simular depois do rebirth).
> O simulador é uma estimativa. Depois do lançamento, compare com os dados reais (Firebase Analytics) e ajuste.

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
