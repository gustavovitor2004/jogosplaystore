# RELATÓRIO — Astro Digger

**Resumo:** Jogo idle de mineração em que você começa na Terra e vai cavando pelo sistema solar e, depois, por planetas de outras estrelas. Em cada planeta você minera, refina, monta a nave pro próximo destino e deixa uma colônia que continua gerando renda.

**Gênero:** Idle / incremental com progressão por planetas

**Mecânica principal:**
Minerar → refinar (minério → barra → peça) → montar a nave → lançar pro próximo planeta.
O planeta anterior **vira colônia e continua produzindo**. Cada planeta tem um **jeito próprio de minerar**.

### Planetas

**Lançamento (MVP):**
| # | Planeta | Mecânica própria | Minérios-chave |
|---|---------|------------------|----------------|
| 1 | Terra | Tutorial: cavar em camadas de profundidade | Carvão, ferro, cobre |
| 2 | Lua | Gravidade baixa: o minério "quica" e precisa ser coletado | Hélio-3, titânio |
| 3 | Marte | Tempestades de poeira periódicas: ativar escudo ou perder produção | Ferro oxidado, gelo |

**Atualizações: sistema solar**
| Planeta | Mecânica própria |
|---------|------------------|
| Cinturão de Asteroides | Asteroides passam por tempo limitado; mandar drones atrás |
| Júpiter (Europa e Io) | Perfurar o gelo de Europa usando o calor dos vulcões de Io |
| Saturno (anéis e Titã) | Drones coletam rocha e gelo dos anéis girando; metano de Titã vira combustível |
| Urano / Netuno | "Chuva de diamantes" |
| Plutão | Gelo de nitrogênio; fecha o sistema solar |
| Mercúrio / Vênus | Expansão "rumo ao Sol": calor extremo, ácido |

> Gigantes gasosos não têm chão pra cavar, então a mineração neles é feita nas luas e nos anéis.

**Atualizações: outros sistemas (exoplanetas reais)**
| Planeta | Ideia de mecânica (baseada no planeta real) |
|---------|---------------------------------------------|
| Proxima Centauri b | Um lado sempre de dia e o outro sempre de noite: minerar na faixa entre os dois |
| Sistema TRAPPIST-1 | 7 planetas num sistema só: rede de colônias que trocam recursos |
| 55 Cancri e | Superfície de lava, planeta rico em carbono: mineração de diamante com resfriamento |
| Kepler-16b | Dois sóis: ciclos de dia e noite duplos que mudam a produção |
| HD 189733 b | Ventos fortíssimos que, segundo a ciência, podem carregar vidro: coletar no vento |

### Colônias e viagem livre
- **Todo planeta desbloqueado continua produzindo**, online e offline.
- **Viagem livre:** o jogador pode ir para qualquer planeta já desbloqueado, a qualquer momento, de graça. A viagem tem uma animação de cerca de 1 s que **não dá pra pular**, porque ela é um item cosmético.
- **Animação de viagem personalizável:** em eventos sazonais (Halloween, Natal etc.) a animação muda pro tema da época. Quem participou do evento ganha a animação de forma permanente e pode escolher qual usar a qualquer momento, independente da data.
  - A animação **nunca passa de ~1 s**, pra não virar espera chata.
  - As animações são pacotes pequenos baixados sob demanda, o que mantém o APK leve.
  - A posse das animações fica registrada no servidor, então não dá pra liberar editando o save.
- **Bônus de presença:** o planeta onde você está rende mais (toque ativo, eventos locais como as tempestades de Marte e os asteroides de passagem). Os outros planetas rendem no modo automático.
- **Corrente de dependência:** cada planeta novo depende do anterior. A nave e as melhorias do planeta N pedem materiais do planeta N-1 (ex.: a nave de Marte usa titânio da Lua). Mais pra frente, algumas receitas também pedem materiais de planetas mais antigos. É isso que faz o jogador voltar.
- **Balanceamento:** a renda dos planetas antigos sempre ajuda, mas nunca supera a do planeta mais avançado. Cada planeta novo tem uma escala de números bem maior.
- **Desempenho:** só o planeta em que você está é carregado na memória. Os outros são calculados por fórmula, sem gráficos, o que pesa pouco até em celular com 2 GB de RAM.

### Nave
Cada planeta pede uma nave com 4 partes (casco, motor, tanque, navegação). A nave aparece montada na plataforma conforme você avança, e o lançamento é o momento-troféu.

### Rebirth ("Nova Expedição")
Volta tudo pra Terra (colônias inclusive) e dá **Poeira Estelar** proporcional ao progresso. A Poeira compra pontos na **Árvore de Habilidades**:
- ⛏️ Mineração: mais produção
- 🤖 Automação: gerentes, drones, refino automático
- 🚀 Engenharia: naves mais baratas, lançamento mais rápido
- 🌙 Exploração: mais ganho offline, bônus de colônia

### Atualizações planejadas (tipos)
1. Habilidades novas na árvore
2. Skins (nave, minerador, broca)
3. Planetas novos (sistema solar e depois exoplanetas)
4. Eventos temporários

**Inspirado em:** Idle Miner Tycoon, Idle Planet Miner, Deep Town, Egg, Inc.
**O que melhoramos:** cada planeta joga diferente; a nave dá uma meta visível; os planetas formam uma corrente de dependência com viagem livre entre eles; os planetas são reais (inclusive exoplanetas) e trazem curiosidades de verdade.

---

## Avaliação da equipe

- **Design visual (8/10):** 2D vetorial chapado, paleta própria por planeta, referência em ilustração científica. Exoplanetas dão liberdade visual enorme (dois sóis, lava, vidro).
- **Programação (8/10):** Godot 4 (renderizador Compatibility), equipe dividida em 4 frentes (ver abaixo). Colônias produzindo ao mesmo tempo são calculadas por **fórmula**, sem simular nada quadro a quadro, então não pesa no celular.
- **Cibersegurança (7/10):** principais riscos: adiantar relógio, GameGuardian e edição de save. Solução: relógio monotônico, horário do servidor, limite offline, save criptografado com HMAC e moeda premium só no servidor. O Security Foundation ainda precisa ser criado.
- **Monetização (7,5/10):** anúncio recompensado opcional, remover anúncios, skins (renda recorrente a cada atualização), starter pack e passe de evento. Sem loot box.
- **Economia (7/10):** colônias e receitas cruzadas deixam o balanceamento mais complexo. A solução é uma planilha-mestre de curvas e um simulador de progressão antes de cada planeta novo.
- **QA/Riscos (8/10):** o nome novo resolveu o conflito com Idle Miner Tycoon. Continua o risco do concorrente Idle Planet Miner, e o diferencial precisa aparecer nos primeiros 30 segundos.

**Nota de viabilidade geral: 8/10**

## Equipe de programação
| Agente | Foco |
|--------|------|
| 👨‍💻 Programador Core | Gameplay, mineração, refino, nave, colônias, rebirth e árvore |
| 📱 Programador Android | Plugins Kotlin: Play Billing, anúncios, Play Integrity, Keystore |
| ☁️ Programador Backend | Servidor: login, validação de compras, sync de save, anti-trapaça |
| 🖼️ Programador UI/Performance | Telas, animações, números grandes, teste em celular fraco |

## Decisão do Diretor: ✅ APROVADO

## Próximo passo
1. ~~Economia: curvas de custo e produção do MVP~~ ✅ Feito: ver [economia/ECONOMIA.md](economia/ECONOMIA.md)
2. ~~Programador Core: projeto Godot e protótipo da Terra~~ ✅ Feito: ver [codigo/README.md](codigo/README.md). Terra, Lua e Marte jogáveis, com rebirth, árvore de habilidades e compra automática. Ainda sem arte final e sem as mecânicas especiais dos planetas.
3. Cibersegurança + Android + Backend: módulo Security Foundation.
4. Designer Visual: identidade visual e prompts de ícone e telas.
5. Começar a juntar os 12 testadores pro teste fechado obrigatório da Play Store.
