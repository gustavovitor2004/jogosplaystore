# Identidade Visual — Astro Digger

> Feita pelo 🎨 Designer Visual. Prompts prontos em [PROMPTS.md](PROMPTS.md). Cores em [paleta.svg](paleta.svg).

## 1. A ideia em uma frase
**"Um cartaz de exploração espacial dos anos 60 que virou jogo de celular."** Ilustração vetorial chapada, poucas cores por planeta, uma leve textura de papel/serigrafia e formas arredondadas e "gordinhas", fáceis de ler em tela pequena.

## 2. Referências reais (e o que pegamos de cada uma)
| Jogo / referência | O que pegamos | O que fazemos diferente |
|-------------------|---------------|--------------------------|
| **Egg, Inc.** | Interface gordinha e legível; números grandes; o foguete como recompensa visual | Menos "3D de plástico", mais ilustração chapada |
| **Alto's Odyssey** | Paisagens em camadas com degradê suave e silhuetas | Aplicado em **corte lateral** do planeta (o subsolo visível) |
| **Deep Town / fazendas de formiga** | Vista em corte: ver as camadas e as minas lá embaixo | Cada planeta tem sua própria geologia real |
| **Cartazes da NASA "Visions of the Future" (JPL)** | Poucas cores fortes, clima retrô-futurista, tipografia ousada | Nada copiado: só o clima de pôster de viagem |
| **Idle Miner Tycoon** | Personagem simpático que dá rosto ao jogo | Mascote astronauta, não um minerador humano |

## 3. Elementos-chave da marca
- **O símbolo: o foguete-broca.** Um foguete cuja ponta é uma broca espiral. Junta mineração e espaço numa forma só e funciona até em 48 px. É o centro do ícone e do logo.
- **A vista em corte.** Cada planeta aparece "cortado ao meio": superfície e nave em cima, camadas e minas embaixo. É a tela que ninguém mais tem e que conta o jogo num relance.
- **O mascote "Pip".** Um astronautinha redondo, com capacete de vidro e lanterna na testa. Aparece nas recompensas, no tutorial e nos vídeos de divulgação.

## 4. Paletas (hex)
**Interface (vale pra todo o jogo):**
| Uso | Cor |
|-----|-----|
| Fundo noite | `#0B1020` |
| Painel | `#161D33` |
| Créditos / destaque | `#F5A623` (âmbar) |
| Poeira Estelar | `#B388FF` (lilás) |
| Texto secundário | `#8A93B2` |

**Por planeta (5 cores cada, sem fugir disso):**
| Planeta | Cores |
|---------|-------|
| 🌍 Terra | `#6EC1E4` céu · `#4E8F4A` musgo · `#C98B4E` argila · `#8B5A2B` terra · `#5A4A42` rocha |
| 🌙 Lua | `#F2F4F8` brilho · `#C9D6E8` titânio · `#B9BEC9` regolito · `#4A5063` sombra · `#0E1220` espaço |
| 🔴 Marte | `#E8B48A` céu · `#E0915A` poeira · `#C1440E` ferrugem · `#6B2D1F` hematita · `#F1E6DA` gelo |

Regra: **no máximo 5 cores por cena + as da interface.** A cor de cada planeta fica no fundo, nos títulos e nos ícones das minas, então o jogador sabe onde está só de bater o olho.

## 5. Tipografia (fontes gratuitas, licença OFL, uso comercial liberado)
- **Títulos e números grandes:** *Fredoka* (arredondada, amigável, ótima pra números de idle)
- **Textos:** *Nunito* (muito legível em tela pequena, tem todos os acentos)
- Ambas estão no Google Fonts. Quando forem pro jogo, o arquivo da fonte vai junto no projeto (não depende de internet).

## 6. Regras pra NÃO parecer "arte de IA"
1. **Paleta travada:** toda imagem gerada passa por uma etapa de recolorir com as cores acima (Figma, Photopea ou Inkscape). IA adora inventar cores, e a gente corta isso.
2. **Vetorizar ou redesenhar por cima:** ícones e minas são redesenhados/vetorizados a partir da imagem gerada. A IA dá a ideia e o acabamento é nosso.
3. **Nada de:** brilho exagerado, "render 8K", reflexos de vidro em tudo, mãos e dedos, texto gerado pela IA (sempre sai torto), detalhe aleatório que não significa nada.
4. **Mesma luz em tudo:** luz vindo de cima à esquerda, sombra chapada (sem degradê de sombra).
5. **Mesma espessura:** sem contorno, ou contorno de espessura única em tudo. Nunca misturar.
6. **Textura de serigrafia sutil** (grão leve) aplicada por cima de tudo no final. Isso dá a "mão humana" e unifica as peças.
7. **Silhueta primeiro:** se o ícone não for reconhecível pintado de uma cor só, ele é refeito.

## 7. Peças que o jogo precisa (lista de produção)
| Peça | Quantidade | Tamanho de trabalho | Observação |
|------|-----------|---------------------|------------|
| Ícone do app | 1 | 1024×1024 → exporta 512×512 | Ver regras da loja abaixo |
| Ícone adaptativo Android | 3 camadas | 432×432 cada | Frente, fundo e monocromático (Android 13+) |
| Banner da loja (feature graphic) | 1 | 1024×500 | **Fundo NÃO pode ser escuro** |
| Cenário em corte por planeta | 3 | 1080×2400 | Fundo da tela de cada planeta |
| Ícones das minas | 24 (8 por planeta) | 256×256 | Mesmo estilo, cor do planeta |
| Nave por planeta (4 peças + completa) | 3 × 5 | 512×512 | Casco, motor, tanque, navegação |
| Mascote Pip (poses) | 5 | 512×512 | Feliz, cavando, comemorando, dormindo (offline), assustado (tempestade) |
| Fragmento de titânio | 1 | 128×128 | Hoje é um polígono no código |
| Plataforma de lançamento | 1 | 1080×600 | |
| Ícones de interface | ~12 | 96×96 | Créditos, Poeira, barras, escudo, AUTO... |

**Orçamento de peso (👨‍💻 Programador):** toda a arte do jogo deve caber em **até 15 MB**. Imagens em PNG, juntas em "atlas" de no máximo 2048×2048, com compressão ETC2. Fundos podem ser feitos em camadas simples pra pesar pouco.

## 8. Regras da Play Store (conferido em out/2026)
| Peça | Regra |
|------|-------|
| **Ícone** | PNG 32 bits, **512×512**, até 1 MB. Quadrado cheio: a loja arredonda os cantos sozinha (raio de 30%). **Sem sombra, sem texto tipo "GRÁTIS" ou "Nº1"** |
| **Banner (feature graphic)** | JPEG ou PNG 24 bits **sem transparência**, **1024×500**. Não repetir o ícone, não usar fundo branco, preto ou cinza-escuro. Elementos importantes no centro |
| **Screenshots** | De 2 a 8, JPEG ou PNG 24 bits. Pra aparecer nas recomendações da loja: **pelo menos 4 em 1080×1920** (em pé). Mostrar o **jogo de verdade**, sem moldura de celular |

Fontes: [especificação de ícone do Google Play](https://developer.android.com/distribute/google-play/resources/icon-design-specifications) · [recursos de pré-visualização](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en). Confira de novo no Play Console na hora de enviar, porque as regras mudam.

## 9. Plano de screenshots (1080×1920, jogo real)
1. Terra em corte com várias minas trabalhando (primeira impressão: "olha quanta coisa")
2. Nave quase completa na plataforma
3. Animação de viagem pra Lua
4. Lua com fragmentos quicando
5. Marte durante a tempestade, com o escudo
6. Árvore de habilidades cheia
7. Tela "enquanto você estava fora..." com número grande

## 10. Discussão da equipe
- **📣 Marketing:** "O Pip é essencial. Vídeo de TikTok com personagem engaja muito mais que vídeo só de interface."
- **🧪 QA:** "O ícone precisa ser testado em 48 px no meio de outros ícones da loja. Se o foguete-broca não for reconhecido nesse tamanho, simplifica."
- **🔒 Cibersegurança:** "Antes de usar arte de IA comercialmente, confira os termos de uso da ferramenta. O Midjourney, por exemplo, exige plano pago pra uso comercial. Guarde os prompts e as datas de geração (este arquivo + PROMPTS.md já ajudam). E nada de nomes, logos ou personagens de outras marcas nos prompts."
- **👨‍💻 Programador:** "Já apliquei as cores de cada planeta no protótipo (fundo e título mudam por planeta). Quando a arte chegar, a troca começa pelo `scripts/ui/estilo.gd`."
