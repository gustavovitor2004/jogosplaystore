## Cores e peças visuais usadas por todas as telas, pra ficarem iguais.
## Quando a arte final chegar, a troca de visual começa por aqui.
class_name Estilo
extends RefCounted

const COR_FUNDO := Color("0b1020")
const COR_PAINEL := Color("161d33")
const COR_DESTAQUE := Color("f5a623")
const COR_POEIRA := Color("b388ff")
const COR_TEXTO_FRACO := Color("8a93b2")
const COR_SELECIONADO := Color("3d4f8a")

## Cor de cada planeta (design/IDENTIDADE_VISUAL.md): o fundo continua escuro pra
## ler bem, só puxado pro tom do planeta; o título usa a cor forte dele.
const PLANETAS := {
	"terra": {"fundo": Color("0e1a16"), "titulo": Color("7cc46b")},
	"lua": {"fundo": Color("10131c"), "titulo": Color("c9d6e8")},
	"marte": {"fundo": Color("1c0f0c"), "titulo": Color("e0703a")},
}


## Cor de um planeta pelo id; se o planeta ainda não tem paleta, usa a padrão.
static func cor_planeta(id: String, chave: String) -> Color:
	var padrao := {"fundo": COR_FUNDO, "titulo": Color.WHITE}
	return PLANETAS.get(id, padrao).get(chave, padrao[chave])


static func tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_stylebox("normal", "Button", caixa(Color("2a3558")))
	t.set_stylebox("hover", "Button", caixa(Color("34416b")))
	t.set_stylebox("pressed", "Button", caixa(Color("1f2843")))
	t.set_stylebox("disabled", "Button", caixa(Color("1a2036")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color("5a6380"))
	t.set_stylebox("panel", "PanelContainer", caixa(COR_PAINEL))
	return t


static func caixa(cor: Color) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = cor
	c.set_corner_radius_all(14)
	c.set_content_margin_all(14)
	return c


static func label(tamanho: int, cor := Color.WHITE) -> Label:
	var rotulo := Label.new()
	# Texto longo vira "..." em vez de empurrar a tela pra fora em celular estreito.
	rotulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


## Label que quebra linha (pra textos explicativos).
static func paragrafo(tamanho: int, cor := Color.WHITE) -> Label:
	var rotulo := label(tamanho, cor)
	rotulo.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return rotulo


static func botao(texto: String, altura := 80) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, altura)
	return b
