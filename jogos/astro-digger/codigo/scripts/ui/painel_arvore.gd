## Painel "Expedição": mostra o rebirth (Nova Expedição) e a árvore de habilidades.
## Abre por cima da tela principal. Os nós vêm todos do economia.json.
extends Control

const INTERVALO_UI := 0.25

var _lbl_poeira: Label
var _lbl_rebirth_info: Label
var _lbl_rebirth_dica: Label
var _btn_rebirth: Button
var _confirmando := false
var _linhas_nos: Dictionary = {}   # id -> {"nome", "desc", "botao"}
var _acumulador := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var fundo := ColorRect.new()
	fundo.color = Estilo.COR_FUNDO
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
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var titulo := Estilo.label(34)
	titulo.text = "Expedição"
	topo.add_child(titulo)
	var fechar := Estilo.botao("Fechar", 64)
	fechar.custom_minimum_size.x = 150
	fechar.pressed.connect(fechar_painel)
	topo.add_child(fechar)

	_lbl_poeira = Estilo.label(30, Estilo.COR_POEIRA)
	coluna.add_child(_lbl_poeira)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	rolagem.add_child(lista)

	_montar_rebirth(lista)
	for ramo in Economia.ramos():
		var nome_ramo := Estilo.label(22, Estilo.COR_TEXTO_FRACO)
		nome_ramo.text = String(ramo["nome"]).to_upper()
		lista.add_child(nome_ramo)
		for no in ramo["nos"]:
			_linhas_nos[no["id"]] = _montar_no(lista, no)

	Jogo.estado_mudou.connect(_atualizar)


func _process(delta: float) -> void:
	if not visible:
		return
	_acumulador += delta
	if _acumulador >= INTERVALO_UI:
		_acumulador = 0.0
		_atualizar()


func abrir() -> void:
	_confirmando = false
	visible = true
	_atualizar()


func fechar_painel() -> void:
	visible = false


# ---------- montagem ----------

func _montar_rebirth(pai: Node) -> void:
	var painel := PanelContainer.new()
	pai.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)
	var titulo := Estilo.label(28, Estilo.COR_DESTAQUE)
	titulo.text = "Nova Expedição (rebirth)"
	coluna.add_child(titulo)
	_lbl_rebirth_info = Estilo.paragrafo(20, Estilo.COR_TEXTO_FRACO)
	coluna.add_child(_lbl_rebirth_info)
	_lbl_rebirth_dica = Estilo.paragrafo(20, Estilo.COR_POEIRA)
	coluna.add_child(_lbl_rebirth_dica)
	_btn_rebirth = Estilo.botao("")
	_btn_rebirth.pressed.connect(_on_rebirth)
	coluna.add_child(_btn_rebirth)
	var regras := Estilo.paragrafo(18, Estilo.COR_TEXTO_FRACO)
	regras.text = "Volta pra Terra e zera créditos, barras, minas e planetas.\n" \
		+ "Fica com você: Poeira Estelar, árvore de habilidades, skins e animações."
	coluna.add_child(regras)


func _montar_no(pai: Node, no: Dictionary) -> Dictionary:
	var painel := PanelContainer.new()
	pai.add_child(painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	painel.add_child(linha)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(textos)
	var nome := Estilo.label(24)
	var desc := Estilo.paragrafo(18, Estilo.COR_TEXTO_FRACO)
	desc.text = no.get("descricao", "")
	textos.add_child(nome)
	textos.add_child(desc)
	var botao := Estilo.botao("", 80)
	botao.custom_minimum_size.x = 190
	botao.pressed.connect(_on_comprar_no.bind(String(no["id"])))
	linha.add_child(botao)
	return {"nome": nome, "botao": botao}


# ---------- atualização ----------

func _atualizar() -> void:
	if not visible:
		return
	_lbl_poeira.text = "%d Poeira Estelar" % Jogo.poeira

	var ganho := Jogo.poeira_disponivel()
	_lbl_rebirth_info.text = "Créditos nesta expedição: %s\nPoeira se recomeçar agora: +%d" % [
		Formatar.numero(Jogo.creditos_expedicao), ganho,
	]
	var p_req := Economia.planeta_requisito_rebirth()
	if not Jogo.requisito_rebirth_cumprido():
		_lbl_rebirth_dica.text = "Construa a nave de %s pra liberar." % Economia.planetas[p_req]["nome"]
	elif Jogo.rebirth_recomendado():
		_lbl_rebirth_dica.text = "Recomendado: você vai voltar bem mais forte!"
	else:
		_lbl_rebirth_dica.text = "Dica: esperar mais um pouco rende mais Poeira."
	_btn_rebirth.disabled = not Jogo.pode_fazer_rebirth()
	if _confirmando and Jogo.pode_fazer_rebirth():
		_btn_rebirth.text = "Tem certeza? Toque de novo"
	else:
		_confirmando = false
		_btn_rebirth.text = "RECOMEÇAR  (+%d Poeira)" % ganho

	for id in _linhas_nos:
		var linha: Dictionary = _linhas_nos[id]
		var no := Economia.no_arvore(id)
		var nivel := Jogo.nivel_no(id)
		var maximo := int(no["nivel_max"])
		linha["nome"].text = "%s  ·  %d/%d" % [no["nome"], nivel, maximo]
		var botao: Button = linha["botao"]
		if nivel >= maximo:
			botao.text = "Completo"
			botao.disabled = true
		elif not Jogo.no_liberado(id):
			botao.text = "Bloqueado"
			botao.disabled = true
		else:
			botao.text = "%d Poeira" % Economia.custo_no(no, nivel)
			botao.disabled = not Jogo.pode_comprar_no(id)


# ---------- ações ----------

func _on_rebirth() -> void:
	# Duas etapas pra ninguém resetar o jogo sem querer.
	if not _confirmando:
		_confirmando = true
		_atualizar()
		return
	_confirmando = false
	if Jogo.fazer_rebirth() > 0:
		visible = false


func _on_comprar_no(id: String) -> void:
	Jogo.comprar_no(id)
