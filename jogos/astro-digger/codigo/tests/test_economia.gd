## Testes automáticos do protótipo. Rodam sem abrir janela:
##   godot --headless --path . -s res://tests/test_economia.gd
## Saída "TODOS OS TESTES PASSARAM" = tudo certo. Qualquer FALHOU = algo quebrou.
extends SceneTree

const SAVE_TESTE := "user://save_teste.json"

# Carregado só depois dos autoloads existirem (jogo.gd usa o autoload Economia).
var _jogo_script: GDScript
var _falhas := 0
var _total := 0


func _initialize() -> void:
	# Espera um quadro pros autoloads (Economia, Jogo) estarem prontos.
	await process_frame
	# Protege o save de verdade do jogador: o Jogo dos testes só escreve no arquivo de teste.
	root.get_node("Jogo").caminho_save = SAVE_TESTE
	_jogo_script = load("res://scripts/autoload/jogo.gd")
	_testar_formulas()
	_testar_formatar()
	_testar_compras()
	_testar_nave()
	_testar_offline()
	_testar_save()
	_testar_mecanicas()
	_testar_arvore()
	_testar_rebirth()
	_testar_ritmo_inicial()
	await _testar_viagem()
	await _testar_telas()
	print("")
	if _falhas == 0:
		print("TODOS OS TESTES PASSARAM (%d)" % _total)
	else:
		print("%d DE %d TESTES FALHARAM" % [_falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	_total += 1
	if condicao:
		print("  ok      ", descricao)
	else:
		_falhas += 1
		print("  FALHOU  ", descricao)


func _perto(a: float, b: float, tolerancia := 1e-6) -> bool:
	return abs(a - b) <= tolerancia * max(1.0, abs(b))


func _jogo_novo() -> Node:
	var jogo: Node = _jogo_script.new() if _jogo_script and _jogo_script.can_instantiate() else null
	if jogo == null:
		_checar(false, "jogo.gd compila e pode ser criado")
		quit(1)
		return null
	jogo.caminho_save = SAVE_TESTE
	jogo.novo_jogo()
	return jogo


# ---------- testes ----------

func _testar_formulas() -> void:
	print("Fórmulas da economia (iguais ao simulador.py):")
	var eco: Node = root.get_node("Economia")
	var mina: Dictionary = eco.mina(0, 0)
	_checar(_perto(eco.custo_n(mina, 0, 1), 10.0), "1º nível da mina da Terra custa 10")
	_checar(_perto(eco.custo_n(mina, 0, 3), 10.0 + 11.5 + 13.225), "comprar 3 níveis = soma dos 3 custos")
	_checar(eco.multiplicador_marcos(9) == 1.0 and eco.multiplicador_marcos(10) == 2.0 \
		and eco.multiplicador_marcos(25) == 4.0, "marcos dobram a produção no nv 10 e 25")
	_checar(_perto(eco.producao_mina(0, 0, 10), 20.0), "mina nv 10 = 1 x 10 x 2 = 20/s")
	_checar(eco.proximo_marco(10) == 25 and eco.proximo_marco(600) == -1, "próximo marco")
	var ok := true
	for dinheiro in [5.0, 10.0, 99.0, 1234.5, 1e6, 3.3e9]:
		for nivel in [0, 7, 40]:
			var n: int = eco.max_compravel(mina, nivel, dinheiro)
			if n > 0 and eco.custo_n(mina, nivel, n) > dinheiro:
				ok = false
			if eco.custo_n(mina, nivel, n + 1) <= dinheiro:
				ok = false
	_checar(ok, "botão MÁX compra o máximo possível, sem passar do dinheiro")
	_checar(eco.destino_nave(0) == 1 and eco.destino_nave(2) == -1, "naves: Terra -> Lua, Marte -> em breve")
	var oito := true
	for planeta in eco.planetas:
		oito = oito and planeta["minas"].size() == 8
	_checar(oito, "cada planeta tem 8 minas")


func _testar_formatar() -> void:
	print("Formatação de números:")
	_checar(Formatar.numero(5) == "5", "5 -> 5")
	_checar(Formatar.numero(0.25) == "0,2", "0,25 -> 0,2")
	_checar(Formatar.numero(999) == "999", "999 -> 999")
	_checar(Formatar.numero(1234567) == "1,23M", "1234567 -> 1,23M")
	_checar(Formatar.numero(999999) == "1,00M", "999999 -> 1,00M (não 1000,00K)")
	_checar(Formatar.numero(1e36) == "1,00aa", "10^36 -> 1,00aa")


func _testar_compras() -> void:
	print("Compras:")
	var jogo := _jogo_novo()
	_checar(jogo.comprar_mina(0, 0, 1), "compra o 1º nível da mina com os 10 créditos iniciais")
	_checar(not jogo.comprar_mina(0, 1, 1), "não compra a 2ª mina sem dinheiro")
	jogo.creditos = 1e9
	_checar(jogo.comprar_mina(0, 0, -1) and jogo.minas[0][0] > 100, "MÁX compra vários níveis de uma vez")
	_checar(not jogo.comprar_mina(1, 0, 1), "não compra mina da Lua antes de chegar lá")
	_checar(jogo.creditos >= 0.0, "créditos nunca ficam negativos")
	jogo.free()


func _testar_nave() -> void:
	print("Nave e viagem:")
	var jogo := _jogo_novo()
	_checar(not jogo.pode_lancar(0), "nave não lança sem barras")
	jogo.barras[0] = 12000.0
	_checar(jogo.pode_lancar(0), "com 12 mil Barras de Ferro a nave da Terra lança")
	_checar(jogo.lancar_nave(0) == 1 and jogo.desbloqueados == 2, "lançar libera a Lua")
	_checar(jogo.barras[0] < 1.0, "as barras foram gastas")
	_checar(not jogo.pode_lancar(0), "não dá pra lançar a mesma nave duas vezes")
	jogo.free()
	if FileAccess.file_exists(SAVE_TESTE):
		DirAccess.remove_absolute(SAVE_TESTE)


func _testar_offline() -> void:
	print("Offline:")
	var jogo := _jogo_novo()
	jogo.minas[0][0] = 10   # 20 créditos/s sem presença
	jogo.planeta_atual = 0
	jogo.creditos = 0.0
	jogo.aplicar_offline(10.0 * 3600.0)
	_checar(_perto(jogo.creditos, 20.0 * 4.0 * 3600.0 * 0.5), "10 h fora rendem só 4 h a 50%")
	jogo.free()


func _testar_save() -> void:
	print("Save:")
	var jogo := _jogo_novo()
	jogo.creditos = 4242.0
	jogo.minas[0][1] = 7
	jogo.barras[0] = 99.0
	jogo.salvar()
	var outro := _jogo_novo()
	outro.carregar()
	_checar(outro.minas[0][1] == 7 and _perto(outro.barras[0], 99.0), "save guarda níveis e barras")
	_checar(outro.creditos >= 4242.0, "save guarda créditos")
	var arquivo := FileAccess.open(SAVE_TESTE, FileAccess.WRITE)
	arquivo.store_string("{lixo corrompido")
	arquivo.close()
	var terceiro := _jogo_novo()
	terceiro.carregar()
	_checar(terceiro.minas[0][1] == 0, "save corrompido não trava: começa do zero")
	for j in [jogo, outro, terceiro]:
		j.free()

	# Save do protótipo antigo (v1: 3 minas, listas por posição) é convertido.
	arquivo = FileAccess.open(SAVE_TESTE, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({
		"versao": 1, "creditos": 500.0, "minas": [[12, 7, 3], [4, 0, 0], [0, 0, 0]],
		"refinarias": [5, 1, 0], "barras": [100.0, 2.0, 0.0], "naves_prontas": [true, false, false],
		"desbloqueados": 2, "planeta_atual": 1, "salvo_em": Time.get_unix_time_from_system(),
	}))
	arquivo.close()
	var antigo := _jogo_novo()
	antigo.carregar()
	var eco: Node = root.get_node("Economia")
	var i_caverna := -1
	for i in eco.planetas[0]["minas"].size():
		if eco.mina(0, i)["id"] == "caverna":
			i_caverna = i
	_checar(antigo.minas[0][0] == 12 and antigo.minas[0][i_caverna] == 7 and antigo.minas[0][7] == 3,
		"save antigo (v1) é convertido: cada mina volta pro lugar certo pelo id")
	_checar(antigo.desbloqueados == 2 and antigo.planeta_atual == 1 and antigo.naves_prontas[0] and antigo.refinarias[0] == 5,
		"save antigo mantém planetas, nave e refinaria")
	antigo.free()
	DirAccess.remove_absolute(SAVE_TESTE)


## Joga sozinho (mesma estratégia do simulador) até chegar em Marte ou acabar o tempo.
## Retorna os segundos até cada planeta: {1: Lua, 2: Marte}.
func _jogar_ate_marte(jogo: Node, limite := 3600.0) -> Dictionary:
	var t := 0.0
	var chegadas := {}
	while t < limite and jogo.desbloqueados < 3:
		jogo.comprar_automatico(1000)
		var p: int = jogo.desbloqueados - 1
		if jogo.pode_lancar(p):
			var destino: int = jogo.lancar_nave(p)
			jogo.planeta_atual = destino     # fora da árvore de cenas não há animação
			chegadas[destino] = t
		jogo.produzir(1.0, true, 1.0)
		t += 1.0
	return chegadas


func _testar_ritmo_inicial() -> void:
	print("Ritmo da 1ª sessão (jogador automático):")
	var jogo := _jogo_novo()
	var chegadas := _jogar_ate_marte(jogo)
	_checar(chegadas.has(1) and chegadas[1] < 15 * 60, "chega na Lua em menos de 15 min (%s s)" % str(chegadas.get(1)))
	_checar(chegadas.has(2) and chegadas[2] < 45 * 60, "chega em Marte em menos de 45 min (%s s)" % str(chegadas.get(2)))

	# 2ª expedição com ~10 Poeira gastos como um jogador faria no 1º rebirth.
	var forte := _jogo_novo()
	forte.poeira = 10
	for id in ["brocas_afiadas", "brocas_afiadas", "brocas_afiadas", "refino_rapido", "refino_rapido", "projeto_enxuto"]:
		forte.comprar_no(id)
	var chegadas_forte := _jogar_ate_marte(forte)
	_checar(chegadas_forte.has(2) and chegadas.has(2) and chegadas_forte[2] < chegadas[2] * 0.75,
		"com a árvore, Marte chega bem mais rápido (%s s contra %s s)" % [str(chegadas_forte.get(2)), str(chegadas.get(2))])
	jogo.free()
	forte.free()
	_apagar_save_teste()


func _apagar_save_teste() -> void:
	if FileAccess.file_exists(SAVE_TESTE):
		DirAccess.remove_absolute(SAVE_TESTE)


func _testar_arvore() -> void:
	print("Árvore de habilidades:")
	var jogo := _jogo_novo()
	_checar(not jogo.comprar_no("brocas_afiadas"), "sem Poeira não compra nada")
	jogo.poeira = 10
	_checar(not jogo.comprar_no("toque_pesado"), "nó bloqueado sem ponto no anterior do ramo")
	_checar(jogo.comprar_no("brocas_afiadas") and jogo.poeira == 9, "1º nível de Brocas custa 1")
	_checar(jogo.comprar_no("brocas_afiadas") and jogo.poeira == 7, "2º nível custa 2 (cada nível +1)")
	jogo.minas[0][0] = 10
	_checar(_perto(jogo.producao_mina_no_nivel(0, 0, 10), 20.0 * 1.5), "Brocas nv 2 = +50% de produção")
	_checar(jogo.comprar_no("toque_pesado"), "com Brocas, o Toque Pesado libera")
	jogo.poeira = 100
	jogo.comprar_no("refino_rapido")
	jogo.comprar_no("gerente_inicial")
	jogo.comprar_no("compra_automatica")
	jogo.comprar_no("drones_de_colonia")
	_checar(_perto(jogo.multiplicador_planeta(1), 1.5), "Drones: planeta sem presença rende +50%")
	jogo.comprar_no("projeto_enxuto")
	jogo.comprar_no("capital_inicial")
	jogo.comprar_no("plataforma_pronta")
	_checar(_perto(jogo.requisitos_nave(0)[0], 12000.0 * 0.95 * 0.75), "Projeto Enxuto + Plataforma Pronta barateiam a nave da Terra")
	var antes: int = jogo.poeira
	for k in 20:
		jogo.comprar_no("brocas_afiadas")
	_checar(jogo.nivel_no("brocas_afiadas") == 10 and jogo.poeira < antes, "não passa do nível máximo (10)")
	jogo.free()
	_apagar_save_teste()


func _testar_rebirth() -> void:
	print("Rebirth (Nova Expedição):")
	var jogo := _jogo_novo()
	jogo.creditos_expedicao = 1e14   # (1e14 / 1e11) ^ (1/3) = 10 Poeira
	_checar(not jogo.pode_fazer_rebirth(), "não libera antes de construir a nave de Marte")
	jogo.desbloqueados = 3
	jogo.planeta_atual = 2
	jogo.naves_prontas[2] = true
	_checar(jogo.poeira_disponivel() == 10, "1e14 créditos na expedição = 10 Poeira")
	_checar(jogo.rebirth_recomendado(), "10 Poeira na 1ª vez = recomendado")
	jogo.poeira = 4   # Brocas (1) + Refino (1) + Gerente Inicial (2)
	jogo.comprar_no("brocas_afiadas")
	jogo.comprar_no("refino_rapido")
	jogo.comprar_no("gerente_inicial")
	var poeira_antes: int = jogo.poeira
	_checar(jogo.fazer_rebirth() == 10, "rebirth rende os 10 Poeira")
	_checar(jogo.poeira == poeira_antes + 10 and jogo.poeira_total == 10 and jogo.expedicoes == 1, "Poeira e contagem de expedições ficam")
	_checar(jogo.desbloqueados == 1 and jogo.planeta_atual == 0 and jogo.creditos_expedicao == 0.0, "volta pra Terra e zera a expedição")
	_checar(jogo.nivel_no("brocas_afiadas") == 1, "a árvore fica")
	_checar(jogo.minas[0][0] == 10, "Gerente Inicial: começa com a Superfície no nv 10")
	_checar(not jogo.pode_fazer_rebirth(), "precisa construir a nave de Marte de novo")

	jogo.salvar()
	var outro := _jogo_novo()
	outro.carregar()
	_checar(outro.poeira == jogo.poeira and outro.nivel_no("gerente_inicial") == 1 and outro.expedicoes == 1,
		"save guarda Poeira, árvore e expedições")
	jogo.free()
	outro.free()
	_apagar_save_teste()


## Usa o Jogo de verdade (autoload) pra testar a viagem com a animação de ~1 s.
func _testar_viagem() -> void:
	print("Viagem livre:")
	var jogo: Node = root.get_node("Jogo")
	jogo.caminho_save = SAVE_TESTE
	jogo.novo_jogo()
	jogo.viajar(1)
	_checar(not jogo.viajando and jogo.planeta_atual == 0, "não viaja pra planeta bloqueado")
	jogo.desbloqueados = 2
	jogo.viajar(1)
	_checar(jogo.viajando and jogo.planeta_atual == 0, "durante a animação ainda está na Terra")
	jogo.viajar(0)
	_checar(jogo.planeta_atual == 0, "não dá pra começar outra viagem no meio de uma")
	await create_timer(jogo.DURACAO_VIAGEM + 0.2).timeout
	_checar(not jogo.viajando and jogo.planeta_atual == 1, "depois de ~1 s chegou na Lua")
	if FileAccess.file_exists(SAVE_TESTE):
		DirAccess.remove_absolute(SAVE_TESTE)


func _testar_mecanicas() -> void:
	print("Mecânicas dos planetas:")
	var jogo := _jogo_novo()
	var mec = jogo.mecanicas

	# Terra: camadas
	jogo.minas[0] = [30, 25, 20, 10, 0, 0, 0, 0]   # 85 níveis = 2 camadas (40 cada)
	_checar(mec.camadas(0) == 2 and _perto(mec.fator_producao(0, true), 1.2), "Terra: 85 níveis = 2 camadas = +20%")
	var avisos := []
	mec.camada_alcancada.connect(func(_p, indice): avisos.append(indice))
	mec.tick(0.1)
	_checar(avisos == [1], "Terra: avisa a camada nova (com curiosidade)")

	# Marte: tempestade e escudo
	var marte: int = mec.planeta_com("tempestade")
	var c: Dictionary = mec.config(marte)
	var inicio: float = float(c["ciclo_segundos"]) - float(c["duracao_segundos"])
	jogo.desbloqueados = 3
	jogo.planeta_atual = marte
	mec.tempo = inicio - 5.0
	_checar(mec.estado_tempestade(marte) == "aviso" and mec.pode_ativar_escudo(), "Marte: aviso antes da tempestade, escudo disponível")
	jogo.planeta_atual = 0
	_checar(not mec.pode_ativar_escudo(), "Marte: escudo só funciona estando em Marte")
	jogo.planeta_atual = marte
	mec.tempo = inicio + 1.0
	_checar(_perto(mec.fator_producao(marte, true), 1.0 - float(c["perda"])), "Marte: tempestade corta 60% da produção")
	_checar(mec.ativar_escudo() and _perto(mec.fator_producao(marte, true), 1.0), "Marte: escudo anula a tempestade")
	mec.tempo = float(c["ciclo_segundos"]) + 1.0
	_checar(not mec.escudo_ativo() and mec.estado_tempestade(marte) == "limpo", "Marte: escudo acaba junto com a tempestade")
	_checar(_perto(mec.fator_producao(marte, false), 1.0 - 0.6 * 90.0 / 420.0), "Marte offline: perda média do ciclo")

	# Lua: fragmentos
	var lua: int = mec.planeta_com("fragmentos")
	var surgidos := []
	mec.fragmento_surgiu.connect(func(id): surgidos.append(id))
	jogo.planeta_atual = 0
	mec.tick(60.0)
	_checar(surgidos.is_empty(), "Lua: fragmentos só aparecem com você na Lua")
	jogo.planeta_atual = lua
	mec.tick(30.0)
	_checar(surgidos.size() == 1, "Lua: fragmento aparece depois de alguns segundos")
	var antes: float = jogo.barras[lua]
	var ganho: float = mec.coletar_fragmento(surgidos[0])
	_checar(ganho >= 10.0 and _perto(jogo.barras[lua], antes + ganho), "Lua: tocar no fragmento dá barras de titânio")
	_checar(mec.coletar_fragmento(surgidos[0]) == 0.0, "Lua: não dá pra coletar o mesmo fragmento 2 vezes")
	mec.tick(30.0)
	mec.tick(7.0)
	_checar(surgidos.size() == 2 and mec.coletar_fragmento(surgidos[1]) == 0.0, "Lua: fragmento some se ninguém tocar")
	mec.tick(30.0)
	jogo.planeta_atual = 0
	mec.tick(0.1)
	_checar(surgidos.size() == 3 and mec.coletar_fragmento(surgidos[2]) == 0.0, "Lua: fragmento some quando você sai da Lua")
	jogo.free()
	_apagar_save_teste()


## Abre a tela principal e o painel da Expedição em cada planeta, pra pegar
## erro de script na interface (os outros testes só olham a lógica).
func _testar_telas() -> void:
	print("Telas:")
	var jogo: Node = root.get_node("Jogo")
	jogo.caminho_save = SAVE_TESTE
	jogo.novo_jogo()
	var cena_script: PackedScene = load("res://scenes/main.tscn")
	var cena: Node = cena_script.instantiate()
	root.add_child(cena)
	await process_frame
	_checar(cena.get_script() != null and cena.has_method("_atualizar"), "tela principal carrega sem erro")
	jogo.desbloqueados = 3
	var ok := true
	for p in 3:
		jogo.planeta_atual = p
		jogo.mecanicas.tempo = 335.0   # Marte em tempestade
		cena._atualizar()
		await process_frame
		ok = ok and cena._planeta_montado == p
	_checar(ok, "tela monta Terra, Lua e Marte (com painel Especial)")
	cena._painel_arvore.abrir()
	await process_frame
	_checar(cena._painel_arvore.visible, "painel da Expedição abre")
	jogo.planeta_atual = 1   # Lua
	cena._atualizar()
	await process_frame
	cena._on_fragmento_surgiu(999)
	await process_frame
	_checar(cena._camada_fragmentos.get_child_count() == 1, "fragmento da Lua aparece na tela")
	jogo.planeta_atual = 2
	cena._atualizar()
	await process_frame
	_checar(cena._camada_fragmentos.get_child_count() == 0, "fragmento some da tela ao sair da Lua")
	cena.queue_free()
	await process_frame
	jogo.novo_jogo()
	_apagar_save_teste()
