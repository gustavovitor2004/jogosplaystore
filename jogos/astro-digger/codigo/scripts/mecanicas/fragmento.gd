## Fragmento de titânio que quica pela tela da Lua (gravidade baixa).
## Toque nele pra coletar. Física bem simples (uma velocidade e quiques nas bordas)
## pra continuar leve em celular fraco.
extends Control

signal coletado(id: int)

const TAMANHO := 84.0
const GRAVIDADE := 260.0   # baixa de propósito: é a Lua
const COR := Color("c9d6e8")
const COR_BRILHO := Color("ffffff")

var id := 0
var vida := 6.0
var _velocidade := Vector2.ZERO
var _area := Vector2.ZERO
var _forma := PackedVector2Array()
var _ja_coletado := false   # toque pode chegar como mouse E como touch


func iniciar(id_fragmento: int, segundos_de_vida: float, area: Vector2) -> void:
	id = id_fragmento
	vida = segundos_de_vida
	_area = area
	custom_minimum_size = Vector2(TAMANHO, TAMANHO)
	size = custom_minimum_size
	position = Vector2(randf_range(0.0, area.x - TAMANHO), area.y * 0.25)
	_velocidade = Vector2(randf_range(-220.0, 220.0), randf_range(-300.0, -120.0))
	# Pedra com contorno irregular (sorteado uma vez, desenhado sempre igual).
	var centro := Vector2(TAMANHO, TAMANHO) / 2.0
	for k in 7:
		var angulo := TAU * k / 7.0
		_forma.append(centro + Vector2.from_angle(angulo) * TAMANHO * randf_range(0.32, 0.45))
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	vida -= delta
	if vida <= 0.0:
		queue_free()
		return
	_velocidade.y += GRAVIDADE * delta
	position += _velocidade * delta
	if position.y + TAMANHO > _area.y:      # chão: quica perdendo pouca força
		position.y = _area.y - TAMANHO
		_velocidade.y = -abs(_velocidade.y) * 0.85
	if position.x < 0.0 or position.x + TAMANHO > _area.x:   # paredes
		position.x = clamp(position.x, 0.0, _area.x - TAMANHO)
		_velocidade.x = -_velocidade.x
	modulate.a = clamp(vida, 0.0, 1.0)   # some devagar no último segundo
	rotation += delta * 1.5
	pivot_offset = size / 2.0


func _draw() -> void:
	draw_colored_polygon(_forma, COR)
	draw_circle(Vector2(TAMANHO * 0.4, TAMANHO * 0.38), TAMANHO * 0.07, COR_BRILHO)


func _gui_input(evento: InputEvent) -> void:
	var tocou: bool = (evento is InputEventMouseButton and evento.pressed) \
		or (evento is InputEventScreenTouch and evento.pressed)
	if tocou and not _ja_coletado:
		_ja_coletado = true
		coletado.emit(id)
		queue_free()
		accept_event()
