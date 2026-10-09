## Tela principal do protótipo.
##
## A interface é montada por código: é mais fácil de revisar no GitHub e de mudar
## do que uma cena gigante. Os textos são atualizados 10x por segundo (não a cada
## quadro) pra poupar bateria e CPU em celular fraco.
extends Control

const ViagemPadrao := preload("res://scripts/viagens/viagem_padrao.gd")
const PainelArvore := preload("res://scripts/ui/painel_arvore.gd")
const Fragmento := preload("res://scripts/mecanicas/fragmento.gd")

const INTERVALO_UI := 0.1
const MODOS_COMPRA := [1, 10, -1]   # -1 = máximo que der
const SEGUNDOS_AVISO := 4.0
const SEGUNDOS_CURIOSIDADE := 8.0
const COR_TEMPESTADE := Color(0.75, 0.3, 0.1, 0.22)

var _modo_idx := 0
var _acumulador := 0.0
var _planeta_montado := -1
var _desbloqueados_montados := -1

var _lbl_creditos: Label
var _lbl_renda: Label
var _btn_modo: Button
var _btn_expedicao: Button
var _btn_auto: Button
var _barra_planetas: HBoxContainer
var _lbl_planeta: Label
var _lbl_presenca: Label
var _btn_minerar: Button
var _lista: VBoxContainer
var _linhas_minas: Array = []
var _linha_ref: Dictionary = {}
var _nave: Dictionary = {}
var _aviso: Label
var _mec: Dictionary = {}          # painel "Especial" do planeta
var _camada_fragmentos: Control    # onde os fragmentos da Lua quicam
var _tempestade: ColorRect         # tela avermelhada durante a tempestade
var _painel_arvore: Control
var _viagem: Control


func _ready() -> void:
	theme = Estilo.tema()
	_montar_layout()
	Jogo.estado_mudou.connect(_atualizar)
	Jogo.viagem_comecou.connect(_on_viagem_comecou)
	Jogo.rebirth_feito.connect(_on_rebirth_feito)
	Jogo.mecanicas.camada_alcancada.connect(_on_camada_alcancada)
	Jogo.mecanicas.fragmento_surgiu.connect(_on_fragmento_surgiu)
	Jogo.mecanicas.tempestade_mudou.connect(_on_tempestade_mudou)
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

func _montar_layout() -> void:
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

	# Topo: créditos, renda e modo de compra (x1 / x10 / MÁX)
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(info)
	_lbl_creditos = Estilo.label(40, Estilo.COR_DESTAQUE)
	info.add_child(_lbl_creditos)
	_lbl_renda = Estilo.label(22, Estilo.COR_TEXTO_FRACO)
	info.add_child(_lbl_renda)
	_btn_modo = Estilo.botao("", 70)
	_btn_modo.custom_minimum_size.x = 130
	_btn_modo.pressed.connect(_on_trocar_modo)
	topo.add_child(_btn_modo)

	# Expedição (rebirth + árvore) e compra automática
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 10)
	coluna.add_child(acoes)
	_btn_expedicao = Estilo.botao("", 64)
	_btn_expedicao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_expedicao.add_theme_color_override("font_color", Estilo.COR_POEIRA)
	_btn_expedicao.pressed.connect(_on_abrir_expedicao)
	acoes.add_child(_btn_expedicao)
	_btn_auto = Estilo.botao("", 64)
	_btn_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_auto.pressed.connect(_on_trocar_auto)
	acoes.add_child(_btn_auto)

	# Planetas (viagem livre entre os liberados)
	_barra_planetas = HBoxContainer.new()
	_barra_planetas.add_theme_constant_override("separation", 10)
	coluna.add_child(_barra_planetas)

	_lbl_planeta = Estilo.label(34)
	coluna.add_child(_lbl_planeta)
	_lbl_presenca = Estilo.label(20, Estilo.COR_TEXTO_FRACO)
	coluna.add_child(_lbl_presenca)

	_btn_minerar = Estilo.botao("", 120)
	_btn_minerar.add_theme_font_size_override("font_size", 36)
	_btn_minerar.pressed.connect(Jogo.minerar_toque)
	coluna.add_child(_btn_minerar)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	rolagem.add_child(_lista)

	_aviso = Estilo.paragrafo(22, Estilo.COR_DESTAQUE)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_aviso)

	if OS.is_debug_build():
		var resetar := Estilo.botao("Recomeçar do zero (só no teste)", 50)
		resetar.add_theme_font_size_override("font_size", 18)
		resetar.pressed.connect(Jogo.resetar)
		coluna.add_child(resetar)

	_tempestade = ColorRect.new()
	_tempestade.color = COR_TEMPESTADE
	_tempestade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tempestade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tempestade.visible = false
	add_child(_tempestade)

	_camada_fragmentos = Control.new()
	_camada_fragmentos.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada_fragmentos.mouse_filter = Control.MOUSE_FILTER_IGNORE   # só os fragmentos pegam toque
	add_child(_camada_fragmentos)

	_painel_arvore = PainelArvore.new()
	_painel_arvore.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_painel_arvore)

	_viagem = ViagemPadrao.new()
	_viagem.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_viagem)


## Remonta a lista quando muda de planeta ou libera um novo.
func _reconstruir() -> void:
	for filho in _barra_planetas.get_children():
		filho.queue_free()
	for p in Economia.planetas.size():
		var botao := Estilo.botao("", 64)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if p < Jogo.desbloqueados:
			botao.text = Economia.planetas[p]["nome"]
			botao.disabled = p == Jogo.planeta_atual
			if p == Jogo.planeta_atual:   # destaca onde o jogador está
				botao.add_theme_stylebox_override("disabled", Estilo.caixa(Estilo.COR_SELECIONADO))
				botao.add_theme_color_override("font_disabled_color", Estilo.COR_DESTAQUE)
			botao.pressed.connect(Jogo.viajar.bind(p))
		else:
			botao.text = "???"
			botao.disabled = true
		_barra_planetas.add_child(botao)

	for filho in _lista.get_children():
		filho.queue_free()
	_linhas_minas.clear()
	for fragmento in _camada_fragmentos.get_children():   # fragmentos da Lua não seguem você
		fragmento.queue_free()
	var p := Jogo.planeta_atual
	_lbl_planeta.text = Economia.planetas[p]["nome"]
	_criar_painel_mecanica(p)
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
	var nome := Estilo.label(26)
	var info := Estilo.label(20, Estilo.COR_TEXTO_FRACO)
	textos.add_child(nome)
	textos.add_child(info)
	var botao := Estilo.botao("", 80)
	botao.custom_minimum_size.x = 230
	botao.pressed.connect(ao_comprar)
	linha.add_child(botao)
	return {"nome": nome, "info": info, "botao": botao}


## Painel "Especial" no topo da lista: mostra a mecânica própria do planeta.
func _criar_painel_mecanica(p: int) -> void:
	_mec = {}
	if Jogo.mecanicas.tipo(p) == "":
		return
	_lista.add_child(_titulo_secao("Especial de %s" % Economia.planetas[p]["nome"]))
	var painel := PanelContainer.new()
	_lista.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)
	_mec = {
		"titulo": Estilo.label(24, Estilo.COR_DESTAQUE),
		"info": Estilo.paragrafo(20, Estilo.COR_TEXTO_FRACO),
		"barra": ProgressBar.new(),
		"botao": Estilo.botao("", 72),
	}
	_mec["barra"].show_percentage = false
	_mec["barra"].custom_minimum_size = Vector2(0, 14)
	_mec["botao"].pressed.connect(_on_escudo)
	for chave in ["titulo", "info", "barra", "botao"]:
		coluna.add_child(_mec[chave])


func _criar_painel_nave() -> void:
	var painel := PanelContainer.new()
	_lista.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)
	_nave = {
		"titulo": Estilo.label(26),
		"pecas": Estilo.label(22, Estilo.COR_DESTAQUE),
		"materiais": Estilo.label(20, Estilo.COR_TEXTO_FRACO),
		"botao": Estilo.botao(""),
	}
	_nave["botao"].pressed.connect(_on_lancar)
	for chave in ["titulo", "pecas", "materiais", "botao"]:
		coluna.add_child(_nave[chave])


func _titulo_secao(texto: String) -> Label:
	var rotulo := Estilo.label(22, Estilo.COR_TEXTO_FRACO)
	rotulo.text = texto.to_upper()
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

	_btn_expedicao.text = "Expedição  ·  %d Poeira%s" % [Jogo.poeira, "  (!)" if Jogo.rebirth_recomendado() else ""]
	_btn_auto.visible = Jogo.efeito("auto_compra") > 0.0
	_btn_auto.text = "AUTO: ligado" if Jogo.auto_compra_ligada else "AUTO: desligado"

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
		_preencher_botao(linha["botao"], Jogo.orcamento_mina(p, i, modo), nivel == 0)

	var nivel_ref: int = Jogo.refinarias[p]
	_linha_ref["nome"].text = "%s  ·  nv %d" % [Economia.planetas[p]["barra"], nivel_ref]
	_linha_ref["info"].text = "%s/s   ·   estoque %s" % [
		Formatar.numero(Jogo.barras_por_segundo(p)), Formatar.numero(Jogo.barras[p]),
	]
	_preencher_botao(_linha_ref["botao"], Jogo.orcamento_refinaria(p, modo), nivel_ref == 0)

	_atualizar_nave(p)
	_atualizar_mecanica(p)


func _atualizar_mecanica(p: int) -> void:
	var mec: Mecanicas = Jogo.mecanicas
	var marte := mec.planeta_com("tempestade")
	_tempestade.visible = p == marte and mec.tempestade_ativa_em(marte)
	if _mec.is_empty():
		return
	var c := mec.config(p)
	var barra: ProgressBar = _mec["barra"]
	var botao: Button = _mec["botao"]
	match mec.tipo(p):
		"camadas":
			var prog := mec.progresso_camadas(p)
			var nomes: Array = c["camadas"]
			var bonus := int(round(float(c["bonus_por_camada"]) * prog["camada"] * 100.0))
			_mec["titulo"].text = "Profundidade: %s" % (nomes[prog["camada"] - 1]["nome"] if prog["camada"] > 0 else "Superfície")
			if prog["camada"] < prog["total"]:
				_mec["info"].text = "Camada %d de %d  ·  +%d%% na Terra
Próxima: %s (%d / %d níveis nas minas)" % [
					prog["camada"], prog["total"], bonus, nomes[prog["camada"]]["nome"], prog["niveis"], prog["proxima"],
				]
				var anterior: int = int(prog["camada"]) * int(c["niveis_por_camada"])
				barra.max_value = prog["proxima"] - anterior
				barra.value = prog["niveis"] - anterior
			else:
				_mec["info"].text = "Todas as %d camadas!  ·  +%d%% na Terra" % [prog["total"], bonus]
				barra.max_value = 1
				barra.value = 1
			barra.visible = true
			botao.visible = false
		"fragmentos":
			_mec["titulo"].text = "Gravidade baixa"
			_mec["info"].text = "Fragmentos de titânio quicam pela tela de tempos em tempos. Toque neles antes que sumam pra ganhar barras!"
			barra.visible = false
			botao.visible = false
		"tempestade":
			var estado := mec.estado_tempestade(p)
			var segundos := mec.segundos_tempestade(p)
			var perda := int(float(c["perda"]) * 100.0)
			barra.visible = false
			botao.visible = estado != "limpo"
			botao.disabled = not mec.pode_ativar_escudo()
			if mec.escudo_ativo():
				_mec["titulo"].text = "Escudo ativo!"
				_mec["info"].text = "A tempestade não te atinge. (%s)" % Formatar.tempo(segundos)
				botao.text = "Escudo ligado"
			elif estado == "tempestade":
				_mec["titulo"].text = "TEMPESTADE DE POEIRA!"
				_mec["info"].text = "Produção de Marte -%d%%  ·  acaba em %s" % [perda, Formatar.tempo(segundos)]
				botao.text = "ATIVAR ESCUDO"
			elif estado == "aviso":
				_mec["titulo"].text = "Tempestade chegando em %s!" % Formatar.tempo(segundos)
				_mec["info"].text = "Ative o escudo pra não perder %d%% da produção." % perda
				botao.text = "ATIVAR ESCUDO"
			else:
				_mec["titulo"].text = "Céu limpo"
				_mec["info"].text = "Próxima tempestade em %s. Fique de olho: o escudo só funciona com você em Marte." % Formatar.tempo(segundos)


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
		if destino >= 0:
			_nave["pecas"].text = "Rota liberada para %s" % nome_destino
		else:
			_nave["pecas"].text = "Próximo planeta em breve! Abra a Expedição pro rebirth."
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
	var req := Jogo.requisitos_nave(p)
	for planeta in req:
		linhas.append("%s: %s / %s" % [
			Economia.planetas[planeta]["barra"], Formatar.numero(Jogo.barras[planeta]), Formatar.numero(req[planeta]),
		])
	_nave["materiais"].text = "\n".join(linhas)
	botao.visible = true
	botao.disabled = not Jogo.pode_lancar(p)
	if Jogo.pode_lancar(p):
		botao.text = ("LANÇAR PARA %s!" % nome_destino.to_upper()) if destino >= 0 else "CONCLUIR NAVE!"
	else:
		botao.text = "Juntando barras...  %d%%" % int(progresso * 100.0)


func _mostrar_aviso(texto: String, segundos := SEGUNDOS_AVISO) -> void:
	_aviso.text = texto
	get_tree().create_timer(segundos).timeout.connect(func():
		if _aviso.text == texto:
			_aviso.text = "")


# ---------- ações ----------

func _on_trocar_modo() -> void:
	_modo_idx = (_modo_idx + 1) % MODOS_COMPRA.size()
	_atualizar()


func _on_trocar_auto() -> void:
	Jogo.auto_compra_ligada = not Jogo.auto_compra_ligada
	_atualizar()


func _on_abrir_expedicao() -> void:
	_painel_arvore.abrir()


func _on_comprar_mina(p: int, i: int) -> void:
	Jogo.comprar_mina(p, i, MODOS_COMPRA[_modo_idx])


func _on_comprar_refinaria(p: int) -> void:
	Jogo.comprar_refinaria(p, MODOS_COMPRA[_modo_idx])


func _on_lancar() -> void:
	var p := Jogo.planeta_atual
	var destino := Jogo.lancar_nave(p)
	if destino < 0 and Jogo.naves_prontas[p]:
		_mostrar_aviso("Nave concluída! Rebirth liberado: abra a Expedição.")


func _on_viagem_comecou(_de: int, para: int) -> void:
	_viagem.tocar(Economia.planetas[para]["nome"], Jogo.DURACAO_VIAGEM)


func _on_rebirth_feito(poeira_ganha: int) -> void:
	_mostrar_aviso("+%d Poeira Estelar! Nova expedição começando na Terra." % poeira_ganha)


func _on_escudo() -> void:
	if Jogo.mecanicas.ativar_escudo():
		_atualizar()


func _on_camada_alcancada(p: int, indice: int) -> void:
	var camada: Dictionary = Jogo.mecanicas.config(p)["camadas"][indice]
	_mostrar_aviso("Camada nova: %s! Curiosidade: %s" % [camada["nome"], camada["fato"]], SEGUNDOS_CURIOSIDADE)


func _on_fragmento_surgiu(id: int) -> void:
	var fragmento := Fragmento.new()
	_camada_fragmentos.add_child(fragmento)
	fragmento.iniciar(id, Jogo.mecanicas.vida_fragmento(), _camada_fragmentos.size)
	fragmento.coletado.connect(_on_fragmento_coletado)


func _on_fragmento_coletado(id: int) -> void:
	var ganho := Jogo.mecanicas.coletar_fragmento(id)
	if ganho > 0.0:
		var lua := Jogo.mecanicas.planeta_com("fragmentos")
		_mostrar_aviso("+%s %s" % [Formatar.numero(ganho), Economia.planetas[lua]["barra"]], 2.0)


func _on_tempestade_mudou(estado: String) -> void:
	var marte := Jogo.mecanicas.planeta_com("tempestade")
	if estado == "aviso" and Jogo.planeta_atual == marte:
		_mostrar_aviso("Tempestade de poeira chegando em Marte! Ative o escudo.")
