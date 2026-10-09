## Jogo: guarda o estado do jogador (créditos, níveis, barras, planetas, Poeira,
## árvore) e as ações (comprar, lançar nave, viajar, rebirth). A tela só lê daqui
## e chama as ações.
##
## PROTÓTIPO: o save ainda é um JSON simples e o tempo offline usa o relógio do
## aparelho. O módulo Security Foundation vai trocar isso por save criptografado
## com HMAC e por horário do servidor. Os pontos de troca estão marcados com
## "SECURITY FOUNDATION".
extends Node

signal estado_mudou
signal viagem_comecou(de: int, para: int)
signal planeta_desbloqueado(p: int)
signal rebirth_feito(poeira_ganha: int)

## v2: dados por planeta/mina guardados pelo id (não pela posição), pra
## atualizações poderem adicionar planetas e minas sem bagunçar o progresso.
const VERSAO_SAVE := 2
## Ordem das minas no save v1 (protótipo com 3 minas por planeta), pra converter.
const MINAS_SAVE_V1 := {
	"terra": ["superficie", "caverna", "nucleo"],
	"lua": ["cratera", "mar_lunar", "manto"],
	"marte": ["planicie", "canion", "calota"],
}
const CAMINHO_SAVE := "user://save.json"
const INTERVALO_AUTOSAVE := 10.0
## Duração fixa da animação de viagem. Não dá pra pular porque é um item cosmético.
const DURACAO_VIAGEM := 1.0
## A compra automática age 2x por segundo (rápido o bastante e leve pro celular).
const INTERVALO_AUTO_COMPRA := 0.5
## O rebirth é "recomendado" quando rende pelo menos isto, ou tanto quanto
## a Poeira já ganha antes (mesma regra usada no simulador).
const POEIRA_MINIMA_RECOMENDADA := 8

# --- estado da expedição atual (zera no rebirth) ---
var creditos := 0.0
var creditos_expedicao := 0.0  # tudo que foi ganho nesta expedição (define a Poeira)
var minas: Array = []          # minas[planeta][mina] = nível
var refinarias: Array = []     # refinarias[planeta] = nível
var barras: Array = []         # barras[planeta] = estoque
var naves_prontas: Array = []  # naves_prontas[planeta] = true depois de lançada/concluída
var desbloqueados := 1         # quantos planetas já foram liberados (Terra = 1)
var planeta_atual := 0         # onde o jogador está (ganha o bônus de presença)

# --- progresso permanente (sobrevive ao rebirth) ---
var poeira := 0                # Poeira Estelar disponível pra gastar
var poeira_total := 0          # toda a Poeira já ganha
var expedicoes := 0            # quantos rebirths já fez
var arvore: Dictionary = {}    # {id_do_nó: nível}
var auto_compra_ligada := false

var viajando := false
var ganho_offline := 0.0       # pra tela mostrar "enquanto você estava fora..."
var caminho_save := CAMINHO_SAVE  # os testes trocam por um arquivo próprio

var _efeitos: Dictionary = {}  # soma dos efeitos da árvore, recalculada só quando ela muda
var _tempo_autosave := 0.0
var _tempo_auto_compra := 0.0
var _pausado_em := 0.0


func _ready() -> void:
	novo_jogo()
	carregar()


func _process(delta: float) -> void:
	produzir(delta, true, 1.0)
	if auto_compra_ativa():
		_tempo_auto_compra += delta
		if _tempo_auto_compra >= INTERVALO_AUTO_COMPRA:
			_tempo_auto_compra = 0.0
			comprar_automatico()
	_tempo_autosave += delta
	if _tempo_autosave >= INTERVALO_AUTOSAVE:
		salvar()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# Android pode matar o app em segundo plano a qualquer momento: salva já.
			_pausado_em = _agora()
			salvar()
		NOTIFICATION_APPLICATION_RESUMED:
			if _pausado_em > 0.0:
				aplicar_offline(_agora() - _pausado_em)
				_pausado_em = 0.0
				estado_mudou.emit()


## Jogo do zero: apaga também a Poeira e a árvore.
func novo_jogo() -> void:
	poeira = 0
	poeira_total = 0
	expedicoes = 0
	arvore = {}
	auto_compra_ligada = false
	_recalcular_efeitos()
	_nova_expedicao()
	ganho_offline = 0.0


## Começa uma expedição: zera planetas e economia, mantém Poeira e árvore,
## e aplica os bônus de início da árvore.
func _nova_expedicao() -> void:
	creditos = float(Economia.global.get("creditos_iniciais", 10)) + efeito("creditos_iniciais")
	creditos_expedicao = 0.0
	minas = []
	refinarias = []
	barras = []
	naves_prontas = []
	for planeta in Economia.planetas:
		var niveis := []
		niveis.resize(planeta["minas"].size())
		niveis.fill(0)
		minas.append(niveis)
		refinarias.append(0)
		barras.append(0.0)
		naves_prontas.append(false)
	minas[0][0] = int(efeito("inicia_mina_terra_nivel"))   # Gerente Inicial
	desbloqueados = 1
	planeta_atual = 0
	viajando = false


# ---------- árvore de habilidades ----------

## Soma de todos os efeitos com esse nome (valor por nível x nível).
func efeito(nome: String) -> float:
	return _efeitos.get(nome, 0.0)


## Para efeitos que são um multiplicador (ex.: "x2"): 1 se não comprou.
func fator(nome: String) -> float:
	var v := efeito(nome)
	return v if v > 0.0 else 1.0


func _recalcular_efeitos() -> void:
	_efeitos.clear()
	for ramo in Economia.ramos():
		for no in ramo["nos"]:
			var nivel := nivel_no(no["id"])
			if nivel > 0:
				_efeitos[no["efeito"]] = _efeitos.get(no["efeito"], 0.0) + float(no["valor_por_nivel"]) * nivel


func nivel_no(id: String) -> int:
	return int(arvore.get(id, 0))


func no_liberado(id: String) -> bool:
	var anterior := Economia.no_anterior(id)
	return anterior == "" or nivel_no(anterior) > 0


func pode_comprar_no(id: String) -> bool:
	var no := Economia.no_arvore(id)
	if no.is_empty() or not no_liberado(id):
		return false
	var nivel := nivel_no(id)
	return nivel < int(no["nivel_max"]) and poeira >= Economia.custo_no(no, nivel)


func comprar_no(id: String) -> bool:
	if not pode_comprar_no(id):
		return false
	poeira -= Economia.custo_no(Economia.no_arvore(id), nivel_no(id))
	arvore[id] = nivel_no(id) + 1
	_recalcular_efeitos()
	estado_mudou.emit()
	salvar()
	return true


# ---------- rebirth ("Nova Expedição") ----------

func poeira_disponivel() -> int:
	return int(floor(Economia.poeira_base(creditos_expedicao) * (1.0 + efeito("poeira_mult"))))


## O rebirth libera quando a nave do planeta-requisito (Marte) fica pronta.
func requisito_rebirth_cumprido() -> bool:
	var p := Economia.planeta_requisito_rebirth()
	return p >= 0 and naves_prontas[p]


func pode_fazer_rebirth() -> bool:
	return requisito_rebirth_cumprido() and not viajando and poeira_disponivel() > 0


func rebirth_recomendado() -> bool:
	return pode_fazer_rebirth() and poeira_disponivel() >= max(POEIRA_MINIMA_RECOMENDADA, poeira_total)


func fazer_rebirth() -> int:
	if not pode_fazer_rebirth():
		return 0
	var ganho := poeira_disponivel()
	poeira += ganho
	poeira_total += ganho
	expedicoes += 1
	_nova_expedicao()
	rebirth_feito.emit(ganho)
	estado_mudou.emit()
	salvar()
	return ganho


# ---------- produção ----------

func multiplicador_planeta(p: int, online := true) -> float:
	if online and p == planeta_atual:
		return float(Economia.global["bonus_presenca"]) + efeito("bonus_presenca")
	return 1.0 + efeito("producao_fora_de_presenca")   # Drones de Colônia


## Produção de uma mina num nível qualquer, com todos os bônus (menos presença).
func producao_mina_no_nivel(p: int, i: int, nivel: int) -> float:
	var base: float = Economia.producao_mina(p, i, nivel, efeito("multiplicador_por_marco"))
	var bonus := 1.0 + efeito("producao_global")
	if i == 0:
		bonus *= fator("primeira_mina_mult")   # Veio Rico
	return base * bonus


func producao_mina(p: int, i: int, online := true) -> float:
	return producao_mina_no_nivel(p, i, minas[p][i]) * multiplicador_planeta(p, online)


func renda_planeta(p: int, online := true) -> float:
	var total := 0.0
	for i in minas[p].size():
		total += producao_mina(p, i, online)
	return total


func renda_total(online := true) -> float:
	var total := 0.0
	for p in desbloqueados:
		total += renda_planeta(p, online)
	return total


func barras_por_segundo(p: int, online := true) -> float:
	var base: float = Economia.barras_refinaria(p, refinarias[p], efeito("multiplicador_por_marco"))
	return base * (1.0 + efeito("barras_global")) * multiplicador_planeta(p, online)


## Roda a produção de todos os planetas liberados por `segundos`.
func produzir(segundos: float, online: bool, eficiencia: float) -> void:
	var ganho := renda_total(online) * eficiencia * segundos
	creditos += ganho
	creditos_expedicao += ganho
	for p in desbloqueados:
		barras[p] += barras_por_segundo(p, online) * eficiencia * segundos


func valor_toque() -> float:
	var segundos := float(Economia.global["toque_segundos_de_producao"])
	return max(1.0, renda_planeta(planeta_atual) * segundos) * fator("toque_mult")


func minerar_toque() -> void:
	var ganho := valor_toque()
	creditos += ganho
	creditos_expedicao += ganho


# ---------- compras ----------

func mina_liberada(p: int, i: int) -> bool:
	return i == 0 or minas[p][i - 1] > 0


func custo_refinaria_mult() -> float:
	return max(0.1, 1.0 + efeito("refinaria_custo"))   # Refinaria Orbital


## Calcula quanto custa comprar no modo escolhido (1, 10 ou -1 = máximo).
## `mult_custo` aplica descontos da árvore. Retorna {"n": níveis, "custo": créditos}.
func orcamento(item: Dictionary, nivel: int, modo: int, mult_custo := 1.0) -> Dictionary:
	var n := modo
	if modo <= 0:
		n = max(1, Economia.max_compravel(item, nivel, creditos / mult_custo))
	return {"n": n, "custo": Economia.custo_n(item, nivel, n) * mult_custo}


func orcamento_mina(p: int, i: int, modo: int) -> Dictionary:
	return orcamento(Economia.mina(p, i), minas[p][i], modo)


func orcamento_refinaria(p: int, modo: int) -> Dictionary:
	return orcamento(Economia.refinaria(p), refinarias[p], modo, custo_refinaria_mult())


func comprar_mina(p: int, i: int, modo: int) -> bool:
	if p >= desbloqueados or not mina_liberada(p, i):
		return false
	var o := orcamento_mina(p, i, modo)
	if o["custo"] > creditos:
		return false
	creditos -= o["custo"]
	minas[p][i] += o["n"]
	estado_mudou.emit()
	return true


func comprar_refinaria(p: int, modo: int) -> bool:
	if p >= desbloqueados:
		return false
	var o := orcamento_refinaria(p, modo)
	if o["custo"] > creditos:
		return false
	creditos -= o["custo"]
	refinarias[p] += o["n"]
	estado_mudou.emit()
	return true


# ---------- compra automática (nó "Compra Automática") ----------

func auto_compra_ativa() -> bool:
	return auto_compra_ligada and efeito("auto_compra") > 0.0


## Escolhe a melhor compra de 1 nível, com a mesma regra do simulador:
## o mais barato entre a mina que se paga mais rápido e a refinaria que é
## o gargalo da nave. Retorna {} se não houver opção.
func melhor_compra() -> Dictionary:
	var melhor := {}
	for p in desbloqueados:
		for i in minas[p].size():
			if not mina_liberada(p, i):
				continue
			var nivel: int = minas[p][i]
			var custo: float = orcamento_mina(p, i, 1)["custo"]
			var ganho := (producao_mina_no_nivel(p, i, nivel + 1) - producao_mina_no_nivel(p, i, nivel)) \
				* multiplicador_planeta(p)
			if ganho > 0.0 and (melhor.is_empty() or custo / ganho < melhor["retorno"]):
				melhor = {"tipo": "mina", "p": p, "i": i, "custo": custo, "retorno": custo / ganho}

	var frente := desbloqueados - 1
	if nave_em_construcao(frente):
		var gargalo := -1
		var pior := -1.0
		var req := requisitos_nave(frente)
		for planeta in req:
			var falta: float = req[planeta] - barras[planeta]
			if falta <= 0.0:
				continue
			var taxa := barras_por_segundo(planeta)
			var eta := INF if taxa == 0.0 else falta / taxa
			if eta > pior:
				pior = eta
				gargalo = planeta
		if gargalo >= 0:
			var custo_ref: float = orcamento_refinaria(gargalo, 1)["custo"]
			if melhor.is_empty() or custo_ref < melhor["custo"]:
				melhor = {"tipo": "ref", "p": gargalo, "custo": custo_ref}
	return melhor


## Compra o que der (até um limite por vez, pra não travar um quadro).
func comprar_automatico(limite := 25) -> void:
	for _k in limite:
		var opcao := melhor_compra()
		if opcao.is_empty() or opcao["custo"] > creditos:
			return
		if opcao["tipo"] == "mina":
			comprar_mina(opcao["p"], opcao["i"], 1)
		else:
			comprar_refinaria(opcao["p"], 1)


# ---------- nave e viagem ----------

## Barras que a nave do planeta `p` pede, já com os descontos da árvore.
func requisitos_nave(p: int) -> Dictionary:
	var req := Economia.requisitos_nave(p)
	var mult: float = max(0.1, 1.0 + efeito("custo_nave"))   # Projeto Enxuto
	if p == 0 and efeito("casco_terra_pronto") > 0.0:        # Plataforma Pronta
		mult *= 1.0 - 1.0 / float(Economia.planetas[0]["nave"]["partes"].size())
	for planeta in req:
		req[planeta] *= mult
	return req


## De 0 a 1: quanto da nave já dá pra montar com as barras em estoque.
func progresso_nave(p: int) -> float:
	var req := requisitos_nave(p)
	var menor := 1.0
	for planeta in req:
		menor = min(menor, barras[planeta] / req[planeta])
	return clamp(menor, 0.0, 1.0)


## Só a nave do planeta mais avançado está em construção.
func nave_em_construcao(p: int) -> bool:
	return p == desbloqueados - 1 and not naves_prontas[p]


func pode_lancar(p: int) -> bool:
	return nave_em_construcao(p) and progresso_nave(p) >= 1.0


## Gasta as barras, marca a nave como pronta e libera o próximo planeta.
## Retorna o índice do destino, ou -1 se o destino ainda é "em breve".
func lancar_nave(p: int) -> int:
	if not pode_lancar(p):
		return -1
	var req := requisitos_nave(p)
	for planeta in req:
		barras[planeta] -= req[planeta]
	naves_prontas[p] = true
	var destino := Economia.destino_nave(p)
	if destino >= 0:
		desbloqueados = destino + 1
		planeta_desbloqueado.emit(destino)
		if is_inside_tree():
			viajar(destino)
	estado_mudou.emit()
	salvar()
	return destino


## Viagem livre entre planetas liberados. A animação dura DURACAO_VIAGEM e não pula.
func viajar(destino: int) -> void:
	if viajando or destino < 0 or destino >= desbloqueados or destino == planeta_atual:
		return
	viajando = true
	viagem_comecou.emit(planeta_atual, destino)
	await get_tree().create_timer(DURACAO_VIAGEM).timeout
	planeta_atual = destino
	viajando = false
	estado_mudou.emit()


# ---------- offline ----------

func limite_offline_horas() -> float:
	return float(Economia.global["offline_limite_horas"]) + efeito("offline_limite_horas")


func eficiencia_offline() -> float:
	return min(1.0, float(Economia.global["offline_eficiencia"]) + efeito("offline_eficiencia"))


## Aplica os ganhos de quando o app estava fechado (com limite e eficiência).
func aplicar_offline(segundos: float) -> void:
	if segundos <= 0.0:
		return
	var efetivo: float = min(segundos, limite_offline_horas() * 3600.0)
	var antes := creditos
	produzir(efetivo, false, eficiencia_offline())
	# Só avisa o jogador se ficou fora de verdade (não a cada troca rápida de app).
	ganho_offline = creditos - antes if segundos >= 60.0 else 0.0


func _agora() -> float:
	# SECURITY FOUNDATION: trocar pelo horário do servidor + relógio monotônico,
	# pra impedir a trapaça de adiantar o relógio do celular.
	return Time.get_unix_time_from_system()


# ---------- save ----------

func salvar() -> void:
	_tempo_autosave = 0.0
	var dados := {
		"versao": VERSAO_SAVE,
		"creditos": creditos,
		"creditos_expedicao": creditos_expedicao,
		"planetas": _planetas_para_save(),
		"desbloqueados": desbloqueados,
		"planeta_atual": Economia.planetas[planeta_atual]["id"],
		"poeira": poeira,
		"poeira_total": poeira_total,
		"expedicoes": expedicoes,
		"arvore": arvore,
		"auto_compra_ligada": auto_compra_ligada,
		"salvo_em": _agora(),
	}
	# SECURITY FOUNDATION: criptografar + assinar com HMAC (chave na Android Keystore).
	# Escreve num arquivo temporário e depois troca: se o app morrer no meio,
	# o save antigo continua inteiro.
	var temporario := caminho_save + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		push_warning("Não consegui salvar: %s" % FileAccess.get_open_error())
		return
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()
	DirAccess.rename_absolute(temporario, caminho_save)


func carregar() -> void:
	if not FileAccess.file_exists(caminho_save):
		return
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if typeof(dados) != TYPE_DICTIONARY or int(dados.get("versao", 0)) not in [1, VERSAO_SAVE]:
		# Save corrompido ou de versão desconhecida: começa do zero sem travar o jogo.
		push_warning("Save inválido, começando um jogo novo.")
		return
	if int(dados["versao"]) == 1:
		dados = _converter_save_v1(dados)
	_aplicar_save(dados)
	aplicar_offline(_agora() - float(dados.get("salvo_em", _agora())))


func _planetas_para_save() -> Dictionary:
	var resultado := {}
	for p in Economia.planetas.size():
		var niveis := {}
		for i in minas[p].size():
			niveis[Economia.mina(p, i)["id"]] = minas[p][i]
		resultado[Economia.planetas[p]["id"]] = {
			"minas": niveis,
			"refinaria": refinarias[p],
			"barras": barras[p],
			"nave_pronta": naves_prontas[p],
		}
	return resultado


## Copia os valores do save com cuidado: o que o jogo tem e o save não tem
## (planeta, mina ou nó novo de uma atualização) fica no valor inicial, e o que
## o save tem e o jogo não tem mais é ignorado.
func _aplicar_save(dados: Dictionary) -> void:
	creditos = max(0.0, float(dados.get("creditos", creditos)))
	creditos_expedicao = max(0.0, float(dados.get("creditos_expedicao", 0.0)))
	var planetas_salvos: Variant = dados.get("planetas", {})
	if typeof(planetas_salvos) != TYPE_DICTIONARY:
		planetas_salvos = {}
	for p in Economia.planetas.size():
		var salvo: Variant = planetas_salvos.get(Economia.planetas[p]["id"], {})
		if typeof(salvo) != TYPE_DICTIONARY:
			continue
		var niveis: Variant = salvo.get("minas", {})
		if typeof(niveis) == TYPE_DICTIONARY:
			for i in minas[p].size():
				minas[p][i] = max(0, int(niveis.get(Economia.mina(p, i)["id"], 0)))
		refinarias[p] = max(0, int(salvo.get("refinaria", 0)))
		barras[p] = max(0.0, float(salvo.get("barras", 0.0)))
		naves_prontas[p] = bool(salvo.get("nave_pronta", false))
	desbloqueados = clamp(int(dados.get("desbloqueados", 1)), 1, Economia.planetas.size())
	var atual := Economia.indice_planeta(String(dados.get("planeta_atual", "")))
	planeta_atual = clamp(atual, 0, desbloqueados - 1)
	poeira = max(0, int(dados.get("poeira", 0)))
	poeira_total = max(poeira, int(dados.get("poeira_total", 0)))
	expedicoes = max(0, int(dados.get("expedicoes", 0)))
	auto_compra_ligada = bool(dados.get("auto_compra_ligada", false))
	arvore = {}
	var arvore_salva: Variant = dados.get("arvore", {})
	if typeof(arvore_salva) == TYPE_DICTIONARY:
		for id in arvore_salva:
			var no := Economia.no_arvore(String(id))
			if not no.is_empty():   # ignora nós que não existem mais
				arvore[String(id)] = clamp(int(arvore_salva[id]), 0, int(no["nivel_max"]))
	_recalcular_efeitos()


## Converte o save do protótipo antigo (listas por posição) pro formato por id.
func _converter_save_v1(antigo: Dictionary) -> Dictionary:
	var ids := ["terra", "lua", "marte"]
	var planetas := {}
	for k in ids.size():
		var niveis := {}
		var minas_antigas: Array = antigo.get("minas", [])
		if k < minas_antigas.size():
			for i in min(minas_antigas[k].size(), MINAS_SAVE_V1[ids[k]].size()):
				niveis[MINAS_SAVE_V1[ids[k]][i]] = minas_antigas[k][i]
		planetas[ids[k]] = {
			"minas": niveis,
			"refinaria": _item_ou(antigo.get("refinarias", []), k, 0),
			"barras": _item_ou(antigo.get("barras", []), k, 0.0),
			"nave_pronta": _item_ou(antigo.get("naves_prontas", []), k, false),
		}
	var novo := antigo.duplicate()
	novo["planetas"] = planetas
	novo["planeta_atual"] = ids[clamp(int(antigo.get("planeta_atual", 0)), 0, ids.size() - 1)]
	return novo


func _item_ou(lista: Variant, k: int, padrao: Variant) -> Variant:
	return lista[k] if typeof(lista) == TYPE_ARRAY and k < lista.size() else padrao


## Só pra testes: apaga o save e recomeça do zero (inclusive Poeira e árvore).
func resetar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(caminho_save)
	novo_jogo()
	estado_mudou.emit()
