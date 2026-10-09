## Animação de viagem padrão: um foguete atravessa a tela em ~1 segundo.
##
## Não dá pra pular: enquanto ela toca, os toques são bloqueados.
## Cada animação futura (Halloween, Natal, "Pioneiro"...) vai ser outro script
## com a mesma função tocar(), então trocar a skin não mexe no resto do jogo.
extends Control

var _foguete: Polygon2D
var _rotulo: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia toques durante a viagem

	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.08, 0.96)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	_foguete = Polygon2D.new()
	_foguete.polygon = PackedVector2Array([
		Vector2(0, -70), Vector2(28, 10), Vector2(36, 40), Vector2(0, 26), Vector2(-36, 40), Vector2(-28, 10),
	])
	_foguete.color = Color("f5a623")
	add_child(_foguete)

	_rotulo = Label.new()
	_rotulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_size_override("font_size", 40)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)


func tocar(destino_nome: String, duracao: float) -> void:
	_rotulo.text = "Rumo a %s" % destino_nome
	visible = true
	_foguete.position = Vector2(size.x / 2.0, size.y + 80.0)
	var animacao := create_tween()
	animacao.tween_property(_foguete, "position:y", -100.0, duracao) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await animacao.finished
	visible = false
