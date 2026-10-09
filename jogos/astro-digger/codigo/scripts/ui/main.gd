## Tela principal do protótipo.
##
## A interface é montada por código: é mais fácil de revisar no GitHub e de mudar
## do que uma cena gigante. Os textos são atualizados 10x por segundo (não a cada
## quadro) pra poupar bateria e CPU em celular fraco.
extends Control

const ViagemPadrao := preload("res://scripts/viagens/viagem_padrao.gd")

const COR_FUNDO := Color("0b1020")
const COR_PAINEL := Color("161d33")
const COR_DESTAQUE := Color("f5a623")
const COR_TEXTO_FRACO := Color("8a93b2")
const INTERVALO_UI := 0.1
const MODOS_COMPRA := [1, 10, -1]   # -1 = máximo que der
const SEGUNDOS_AVISO := 4.0

var _modo_idx := 0
var _acumulador := 0.0
var _planeta_montado := -1
var _desbloqueados_montados := -1

var _lbl_creditos: Label
var _lbl_renda: Label
var _btn_modo: Button
var _barra_planetas: HBoxContainer
var _lbl_planeta: Label
var _lbl_presenca: Label
var _btn_minerar: Button
var _lista: VBoxContainer
var _linhas_minas: Array = []
var _linha_ref: Dictionary = {}
var _nave: Dictionary = {}
var _aviso: Label
var _viagem: Control


func _ready() -> void:
	_montar_tema()
	_montar_layout()
	Jogo.estado_mudou.connect(_atualizar)
	Jogo.viagem_comecou.connect(_on_viagem_comecou)
	_atualizar()
	if Jogo.ganho_offline > 0.0:
		_mostrar_aviso("Enquanto você estava fora, suas minas renderam %s créditos!" % Formatar.numero(Jogo.ganho_offline))
		Jogo.ganho_offline = 0.0


func _process(delta: float) -> void:
	_acumulador += delta
	if _acumulador >= INTERVALO_UI:
		_acumulador = 0.0
		_atualizar()


# ---------- montagem ----------

func _montar_tema() -> void:
	var tema := Theme.new()
	tema.default_font_size = 26
	tema.set_stylebox("normal", "Button", _caixa(Color("2a3558")))
	tema.set_stylebox("hover", "Button", _caixa(Color("34416b")))
	tema.set_stylebox("pressed", "Button", _caixa(Color("1f2843")))
	tema.set_stylebox("disabled", "Button", _caixa(Color("1a2036")))
	tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	tema.set_color("font_disabled_color", "Button", Color("5a6380"))
	tema.set_stylebox("panel", "PanelContainer", _caixa(COR_PAINEL))
	theme = tema


func _caixa(cor: Color) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = cor
	caixa.set_corner_radius_all(14)
	caixa.set_content_margin_all(14)
	return caixa


func _montar_layout() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 20)
	margem.add_theme_constant_override("margin_right", 20)
	margem.add_theme_constant_override("margin_top", 40)
	margem.add_theme_constant_override("margin_bottom", 20)
	add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	margem.add_child(coluna)

	# Topo: créditos, renda e modo de compra (x1 / x10 / MÁX)
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(info)
	_lbl_creditos = _label(40, COR_DESTAQUE)
	info.add_child(_lbl_creditos)
	_lbl_renda = _label(22, COR_TEXTO_FRACO)
	info.add_child(_lbl_renda)
	_btn_modo = Button.new()
	_btn_modo.custom_minimum_size = Vector2(130, 70)
	_btn_modo.pressed.connect(_on_trocar_modo)
	topo.add_child(_btn_modo)

	# Planetas (viagem livre entre os liberados)
	_barra_planetas = HBoxContainer.new()
	_barra_planetas.add_theme_constant_override("separation", 10)
	coluna.add_child(_barra_planetas)

	_lbl_planeta = _label(34)
	coluna.add_child(_lbl_planeta)
	_lbl_presenca = _label(20, COR_TEXTO_FRACO)
	coluna.add_child(_lbl_presenca)

	_btn_minerar = Button.new()
	_btn_minerar.custom_minimum_size = Vector2(0, 120)
	_btn_minerar.add_theme_font_size_override("font_size", 36)
	_btn_minerar.pressed.connect(_on_minerar)
	coluna.add_child(_btn_minerar)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	rolagem.add_child(_lista)

	_aviso = _label(22, COR_DESTAQUE)
	_aviso.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_aviso)

	if OS.is_debug_build():
		var resetar := Button.new()
		resetar.text = "Recomeçar (só no teste)"
		resetar.add_theme_font_size_override("font_size", 18)
		resetar.pressed.connect(Jogo.resetar)
		coluna.add_child(resetar)

	_viagem = ViagemPadrao.new()
	_viagem.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_viagem)


## Remonta a lista quando muda de planeta ou libera um novo.
func _reconstruir() -> void:
	for filho in _barra_planetas.get_children():
		filho.queue_free()
	for p in Economia.planetas.size():
		var botao := Button.new()
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.custom_minimum_size = Vector2(0, 64)
		if p < Jogo.desbloqueados:
			botao.text = Economia.planetas[p]["nome"]
			botao.disabled = p == Jogo.planeta_atual
			if p == Jogo.planeta_atual:   # destaca onde o jogador está
				botao.add_theme_stylebox_override("disabled", _caixa(Color("3d4f8a")))
				botao.add_theme_color_override("font_disabled_color", COR_DESTAQUE)
			botao.pressed.connect(Jogo.viajar.bind(p))
		else:
			botao.text = "???"
			botao.disabled = true
		_barra_planetas.add_child(botao)

	for filho in _lista.get_children():
		filho.queue_free()
	_linhas_minas.clear()
	var p := Jogo.planeta_atual
	_lbl_planeta.text = Economia.planetas[p]["nome"]
	_lista.add_child(_titulo_secao("Minas"))
	for i in Economia.planetas[p]["minas"].size():
		_linhas_minas.append(_criar_linha(_on_comprar_mina.bind(p, i)))
	_lista.add_child(_titulo_secao("Refinaria"))
	_linha_ref = _criar_linha(_on_comprar_refinaria.bind(p))
	_lista.add_child(_titulo_secao("Nave"))
	_criar_painel_nave()

	_planeta_montado = p
	_desbloqueados_montados = Jogo.desbloqueados


func _criar_linha(ao_comprar: Callable) -> Dictionary:
	var painel := PanelContainer.new()
	_lista.add_child(painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	painel.add_child(linha)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(textos)
	var nome := _label(26)
	var info := _label(20, COR_TEXTO_FRACO)
	textos.add_child(nome)
	textos.add_child(info)
	var botao := Button.new()
	botao.custom_minimum_size = Vector2(230, 80)
	botao.pressed.connect(ao_comprar)
	linha.add_child(botao)
	return {"nome": nome, "info": info, "botao": botao}


func _criar_painel_nave() -> void:
	var painel := PanelContainer.new()
	_lista.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)
	_nave = {
		"titulo": _label(26),
		"pecas": _label(22, COR_DESTAQUE),
		"materiais": _label(20, COR_TEXTO_FRACO),
		"botao": Button.new(),
	}
	_nave["botao"].custom_minimum_size = Vector2(0, 80)
	_nave["botao"].pressed.connect(_on_lancar)
	for chave in ["titulo", "pecas", "materiais", "botao"]:
		coluna.add_child(_nave[chave])


func _titulo_secao(texto: String) -> Label:
	var rotulo := _label(22, COR_TEXTO_FRACO)
	rotulo.text = texto.to_upper()
	return rotulo


func _label(tamanho: int, cor := Color.WHITE) -> Label:
	var rotulo := Label.new()
	# Texto longo vira "..." em vez de empurrar a tela pra fora em celular estreito.
	rotulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


# ---------- atualização ----------

func _atualizar() -> void:
	if Jogo.planeta_atual != _planeta_montado or Jogo.desbloqueados != _desbloqueados_montados:
		_reconstruir()
	var p := Jogo.planeta_atual
	var modo: int = MODOS_COMPRA[_modo_idx]

	_lbl_creditos.text = "%s créditos" % Formatar.numero(Jogo.creditos)
	_lbl_renda.text = "+%s por segundo (todos os planetas)" % Formatar.numero(Jogo.renda_total())
	_btn_modo.text = "x%d" % modo if modo > 0 else "MÁX"
	_lbl_presenca.text = "Você está aqui: produção x%s" % Formatar.numero(Jogo.multiplicador_planeta(p))
	_btn_minerar.text = "MINERAR  +%s" % Formatar.numero(Jogo.valor_toque())

	for i in _linhas_minas.size():
		var linha: Dictionary = _linhas_minas[i]
		var nivel: int = Jogo.minas[p][i]
		linha["nome"].text = "%s  ·  nv %d" % [Economia.mina(p, i)["nome"], nivel]
		if not Jogo.mina_liberada(p, i):
			linha["info"].text = "Libere a mina anterior primeiro"
			linha["botao"].text = "Bloqueada"
			linha["botao"].disabled = true
			continue
		var marco := Economia.proximo_marco(nivel)
		linha["info"].text = "%s/s%s" % [
			Formatar.numero(Jogo.producao_mina(p, i)),
			("   ·   x2 no nv %d" % marco) if marco > 0 else "",
		]
		_preencher_botao(linha["botao"], Jogo.orcamento(Economia.mina(p, i), nivel, modo), nivel == 0)

	var nivel_ref: int = Jogo.refinarias[p]
	_linha_ref["nome"].text = "%s  ·  nv %d" % [Economia.planetas[p]["barra"], nivel_ref]
	_linha_ref["info"].text = "%s/s   ·   estoque %s" % [
		Formatar.numero(Jogo.barras_por_segundo(p)), Formatar.numero(Jogo.barras[p]),
	]
	_preencher_botao(_linha_ref["botao"], Jogo.orcamento(Economia.refinaria(p), nivel_ref, modo), nivel_ref == 0)

	_atualizar_nave(p)


func _preencher_botao(botao: Button, orcamento: Dictionary, liberar: bool) -> void:
	var custo := Formatar.numero(orcamento["custo"])
	botao.text = ("Liberar\n%s" % custo) if liberar else ("+%d nv\n%s" % [orcamento["n"], custo])
	botao.disabled = orcamento["custo"] > Jogo.creditos


func _atualizar_nave(p: int) -> void:
	var destino := Economia.destino_nave(p)
	var nome_destino: String = Economia.planetas[destino]["nome"] if destino >= 0 else "o próximo planeta"
	var botao: Button = _nave["botao"]

	if Jogo.naves_prontas[p]:
		_nave["titulo"].text = "Nave construída!"
		_nave["pecas"].text = ("Rota liberada para %s" % nome_destino) if destino >= 0 else "Próximo planeta em breve!"
		_nave["materiais"].text = ""
		botao.visible = false
		return

	var progresso := Jogo.progresso_nave(p)
	var partes: Array = Economia.planetas[p]["nave"]["partes"]
	var prontas := int(floor(progresso * partes.size()))
	_nave["titulo"].text = "Nave para %s" % nome_destino
	_nave["pecas"].text = "Peças prontas: %d de %d%s" % [
		prontas, partes.size(), ("   ·   próxima: %s" % partes[prontas]) if prontas < partes.size() else "",
	]
	var linhas := []
	var req := Economia.requisitos_nave(p)
	for planeta in req:
		linhas.append("%s: %s / %s" % [
			Economia.planetas[planeta]["barra"], Formatar.numero(Jogo.barras[planeta]), Formatar.numero(req[planeta]),
		])
	_nave["materiais"].text = "\n".join(linhas)
	botao.visible = true
	botao.disabled = not Jogo.pode_lancar(p)
	botao.text = ("LANÇAR PARA %s!" % nome_destino.to_upper()) if Jogo.pode_lancar(p) \
		else "Juntando barras...  %d%%" % int(progresso * 100.0)


func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	get_tree().create_timer(SEGUNDOS_AVISO).timeout.connect(func():
		if _aviso.text == texto:
			_aviso.text = "")


# ---------- ações ----------

func _on_trocar_modo() -> void:
	_modo_idx = (_modo_idx + 1) % MODOS_COMPRA.size()
	_atualizar()


func _on_minerar() -> void:
	Jogo.minerar_toque()


func _on_comprar_mina(p: int, i: int) -> void:
	Jogo.comprar_mina(p, i, MODOS_COMPRA[_modo_idx])


func _on_comprar_refinaria(p: int) -> void:
	Jogo.comprar_refinaria(p, MODOS_COMPRA[_modo_idx])


func _on_lancar() -> void:
	var p := Jogo.planeta_atual
	var destino := Jogo.lancar_nave(p)
	if destino < 0 and Jogo.naves_prontas[p]:
		_mostrar_aviso("Nave pronta! O próximo planeta chega numa atualização.")


func _on_viagem_comecou(_de: int, para: int) -> void:
	_viagem.tocar(Economia.planetas[para]["nome"], Jogo.DURACAO_VIAGEM)
