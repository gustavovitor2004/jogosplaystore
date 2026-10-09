# Prompts de arte — Astro Digger

> Os prompts estão em **inglês** porque os geradores entendem melhor. Siga as regras de [IDENTIDADE_VISUAL.md](IDENTIDADE_VISUAL.md): **toda imagem gerada é recolorida com a paleta e vetorizada ou retocada antes de entrar no jogo.**
>
> Qual ferramenta usar:
> - **Midjourney:** melhor pra ilustração e clima (cenários, mascote, banner sem texto)
> - **Leonardo AI:** bom pra séries consistentes (24 ícones de minas, peças da nave). Use o mesmo *seed* e *style reference*
> - **Ideogram:** o único que escreve texto direito. Use pro **logo** e pra testar o banner com o nome

## Bloco de estilo (cole no fim de todo prompt)
```
flat vector illustration, retro-futuristic 1960s space travel poster style, limited color palette, soft screen-print grain texture, rounded chunky shapes, clean silhouettes, flat shading with single hard shadow, light from top-left, no outlines, mobile game art, readable at small size
```

## Negativo (Leonardo "negative prompt" / Midjourney `--no`)
```
photorealistic, 3d render, octane, glossy, lens flare, bloom, hyperdetailed, 8k, text, letters, watermark, signature, hands, fingers, busy background, noise artifacts, gradient mesh, neon
```
No Midjourney, use a versão curta: `--no photorealistic, 3d render, glossy, text, watermark, lens flare`

---

## 1. Ícone do app (gerar 1024×1024 → exportar 512×512)
**Midjourney**
```
app icon, a chunky rocket whose nose is a golden spiral drill bit, bursting up out of a cross-section of a small planet showing colorful rock layers, deep navy background #0B1020, amber #F5A623 and rust #C1440E accents, centered, bold simple silhouette, [BLOCO DE ESTILO] --ar 1:1 --style raw --s 50 --no photorealistic, 3d render, glossy, text, watermark, lens flare
```
**Leonardo** (mesmo texto, sem os parâmetros `--`, com o negativo acima)

✅ Checklist: reconhecível em 48 px? Sem texto? Sem sombra externa? Ocupa o quadrado inteiro (a loja arredonda os cantos)?

## 2. Ícone adaptativo Android (3 camadas de 432×432)
- **Fundo:** `flat navy background #0B1020 with a subtle amber planet curve at the bottom, [BLOCO DE ESTILO] --ar 1:1`
- **Frente:** o foguete-broca **sozinho, fundo transparente**, ocupando só o círculo central (66% da área). Recorte a partir do ícone principal
- **Monocromático:** a silhueta do foguete-broca em uma cor só (o Android 13+ pinta conforme o tema do celular)

## 3. Logo "ASTRO DIGGER" (Ideogram)
```
game logo text "ASTRO DIGGER", chunky rounded bold letters, the letter O in ASTRO replaced by a small planet with a drill rocket orbiting it, amber #F5A623 letters with dark navy #0B1020 thick outline, retro 1960s space poster typography, flat vector, centered on plain white background
```
Depois: vetorizar, corrigir as letras na mão e trocar pela fonte Fredoka se precisar.

## 4. Banner da loja — feature graphic (1024×500, fundo NÃO escuro)
**Midjourney**
```
wide landscape banner, a cute round astronaut miner with headlamp standing on Mars red dunes next to a tall retro rocket on a launch pad, warm peach sky #E8B48A, the Moon and a blue-green Earth visible in the sky, cross-section of the ground showing glowing mine tunnels, lots of empty space in the center-left for a logo, [BLOCO DE ESTILO] --ar 41:20 --style raw --s 75 --no photorealistic, 3d render, glossy, text, watermark, lens flare
```
Depois: colocar o logo (seção 3) à esquerda. **Não** coloque o ícone do app no banner.

## 5. Mascote "Pip" (512×512, fundo transparente)
**Midjourney** (gere a pose base e depois use `--cref` com ela pra manter o mesmo personagem)
```
character sheet of a small round chubby astronaut miner mascot, big glass dome helmet with a headlamp, tiny pickaxe, white suit with amber #F5A623 details, friendly simple face visible through the helmet (two dot eyes), short stubby limbs, front view, [BLOCO DE ESTILO], plain white background --ar 1:1 --style raw --s 50
```
Poses (troque o começo do prompt):
- `... mascot cheering with arms up, confetti` (recompensa)
- `... mascot digging with a pickaxe, rocks flying` (tutorial)
- `... mascot sleeping inside the helmet, little Z letters as simple shapes` (volta do offline)
- `... mascot holding a glowing shield against a dust storm` (Marte)
- `... mascot riding a rocket, waving` (viagem)

## 6. Cenários em corte (fundo de cada planeta, 1080×2400)
**Terra**
```
vertical cross-section of the Earth's ground, top 20% shows green grass, blue sky #6EC1E4 and a small rocket launch pad, below are horizontal geological layers going deeper: dark soil, sedimentary rock with tiny fossils, an underground water layer, granite, deep crust, glowing orange mantle at the very bottom, small mine tunnels on each layer, palette #6EC1E4 #4E8F4A #C98B4E #8B5A2B #5A4A42, [BLOCO DE ESTILO] --ar 9:20 --style raw --s 50
```
**Lua**
```
vertical cross-section of the Moon's ground, top 20% shows grey cratered surface, black starry sky with the Earth far away, a small launch pad, below are layers of grey regolith, dark basalt, pockets of shiny titanium ore, frozen ice near the bottom, small mine tunnels, palette #F2F4F8 #C9D6E8 #B9BEC9 #4A5063 #0E1220, [BLOCO DE ESTILO] --ar 9:20 --style raw --s 50
```
**Marte**
```
vertical cross-section of Mars ground, top 20% shows red dunes, peach dusty sky #E8B48A, Olympus Mons volcano on the horizon, a small launch pad, below are layers of rust red rock, dark hematite veins, frozen ice layer, deep red core, small mine tunnels, palette #E8B48A #E0915A #C1440E #6B2D1F #F1E6DA, [BLOCO DE ESTILO] --ar 9:20 --style raw --s 50
```

## 7. Ícones das minas (24 no total, 256×256)
**Leonardo** (use **o mesmo seed** e o ícone da 1ª mina como *style reference* pra série ficar consistente)
```
single game icon of [NOME DA MINA], isometric small diorama, centered, [CORES DO PLANETA], [BLOCO DE ESTILO], plain white background
```
| Planeta | O que colocar em [NOME DA MINA] |
|---------|---------------------------------|
| Terra | `a shovel on grass` · `a stone quarry` · `a cave entrance` · `a coal mine cart` · `a copper vein in rock` · `an iron ore deposit` · `a deep drilling tunnel` · `a glowing rocky core` |
| Lua | `a small crater` · `a regolith field with footprints` · `a dark lunar mare` · `ice in a shadowed crater` · `lunar mountains` · `a lava tube cave` · `the dark side of the moon` · `the lunar mantle` |
| Marte | `red plains with rocks` · `iron sand dunes` · `Gale crater` · `Olympus Mons volcano` · `Valles Marineris canyon` · `underground ice` · `polar ice cap` · `the martian core` |

## 8. Naves (por planeta: 4 peças + completa, 512×512)
```
retro rocket [PEÇA] part, chunky rounded shape, [CORES DO PLANETA] with amber #F5A623 details, single object centered, [BLOCO DE ESTILO], plain white background --ar 1:1 --style raw
```
[PEÇA] = `hull` (casco) · `engine with nozzle` (motor) · `fuel tank` (tanque) · `navigation nose cone with antenna` (navegação) · `fully assembled rocket` (completa)

Cada planeta tem nave mais avançada que a anterior: Terra = foguete simples de chapa; Lua = painéis de titânio brilhantes; Marte = blindagem vermelha contra poeira.

## 9. Pequenos
- **Fragmento de titânio:** `a single shiny chunk of titanium ore, pale blue-white #C9D6E8, faceted, tiny sparkle, [BLOCO DE ESTILO], plain white background --ar 1:1`
- **Plataforma de lançamento:** `side view of a small retro rocket launch pad with a metal tower and an amber warning stripe, [BLOCO DE ESTILO] --ar 9:5`
- **Ícones de interface** (gerar em série, 96×96): `coin with a drill symbol` (créditos), `purple stardust swirl` (Poeira), `metal ingot bar` (barras), `round shield` (escudo), `gear with play arrow` (AUTO)

---

## Depois de gerar (passo a passo)
1. Escolha a melhor imagem de cada peça (gere 4 a 8 variações).
2. Recolora com a paleta do planeta (Photopea é grátis: Imagem → Ajustes → Mapa de gradiente, ou pinte por cima).
3. Vetorize os ícones (Inkscape: Caminho → Vetorizar bitmap) e limpe os detalhes inúteis.
4. Aplique o grão de serigrafia no final (uma camada de ruído bem leve, 3–5%).
5. Exporte em PNG no tamanho da tabela da [identidade visual](IDENTIDADE_VISUAL.md#7-peças-que-o-jogo-precisa-lista-de-produção) e salve em `design/arte/` com o nome da peça (ex.: `mina_terra_01_superficie.png`).
6. Anote no fim deste arquivo: ferramenta, data e prompt usados (útil se um dia alguém questionar os direitos da arte).

## Registro de geração
| Peça | Ferramenta | Data | Observação |
|------|-----------|------|------------|
| | | | |
