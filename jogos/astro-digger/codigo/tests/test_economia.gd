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
	_testar_arvore()
	_testar_rebirth()
	_testar_ritmo_inicial()
	await _testar_viagem()
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
