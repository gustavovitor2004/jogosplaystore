## Mecânicas especiais de cada planeta. Os números vêm do economia.json
## (bloco "mecanica" de cada planeta), então dá pra ajustar sem mexer aqui.
##
##   camadas    (Terra): somar níveis nas minas leva a camadas mais fundas, cada uma +10% de produção.
##   fragmentos (Lua):   pedaços de titânio quicam pela tela; tocar dá barras.
##   tempestade (Marte): de tempos em tempos a produção cai; o escudo anula se você estiver lá.
##
## Tudo aqui é leve: só contas simples por quadro, nada de física.
## Planeta novo com mecânica nova = um "tipo" novo aqui + o bloco no JSON.
class_name Mecanicas
extends RefCounted

signal camada_alcancada(p: int, indice: int)
signal fragmento_surgiu(id: int)
signal tempestade_mudou(estado: String)   # "limpo", "aviso" ou "tempestade"

var tempo := 0.0   # relógio das mecânicas: só anda com o jogo aberto

var _jogo: Object   # o Jogo dono (sem tipo pra não criar dependência circular)
var _rng := RandomNumberGenerator.new()
var _proximo_fragmento := 0.0
var _fragmentos: Dictionary = {}   # id -> segundos de vida restantes
var _proximo_id := 1
var _escudo_ate := -1.0
var _estado_tempestade := "limpo"
var _camadas_anunciadas: Dictionary = {}   # planeta -> última camada avisada


func _init(jogo: Object) -> void:
	_jogo = jogo
	_rng.randomize()
	reiniciar()


## Chamado no começo de cada expedição (rebirth).
func reiniciar() -> void:
	_fragmentos.clear()
	_camadas_anunciadas.clear()
	_escudo_ate = -1.0
	_proximo_fragmento = _sortear_intervalo()


func config(p: int) -> Dictionary:
	return Economia.planetas[p].get("mecanica", {})


func tipo(p: int) -> String:
	return String(config(p).get("tipo", ""))


func planeta_com(tipo_mecanica: String) -> int:
	for p in Economia.planetas.size():
		if tipo(p) == tipo_mecanica:
			return p
	return -1


## Multiplicador que a mecânica aplica na produção (créditos e barras) do planeta.
func fator_producao(p: int, online: bool) -> float:
	match tipo(p):
		"camadas":
			return 1.0 + float(config(p)["bonus_por_camada"]) * camadas(p)
		"tempestade":
			var c := config(p)
			if online:
				return 1.0 - float(c["perda"]) if tempestade_ativa_em(p) else 1.0
			# Offline não dá pra usar o escudo: vale a perda média do ciclo.
			return 1.0 - float(c["perda"]) * float(c["duracao_segundos"]) / float(c["ciclo_segundos"])
	return 1.0


## Roda a cada quadro, com o jogo aberto.
func tick(delta: float) -> void:
	tempo += delta
	_tick_fragmentos(delta)
	_tick_tempestade()
	_tick_camadas()


# ---------- Terra: camadas ----------

func camadas(p: int) -> int:
	var c := config(p)
	var soma := 0
	for nivel in _jogo.minas[p]:
		soma += nivel
	return min(c["camadas"].size(), soma / int(c["niveis_por_camada"]))


## {"camada": índice atual, "total": quantas existem, "niveis": níveis somados, "proxima": níveis pra próxima}
func progresso_camadas(p: int) -> Dictionary:
	var c := config(p)
	var soma := 0
	for nivel in _jogo.minas[p]:
		soma += nivel
	var atual := camadas(p)
	return {
		"camada": atual,
		"total": c["camadas"].size(),
		"niveis": soma,
		"proxima": (atual + 1) * int(c["niveis_por_camada"]),
	}


func _tick_camadas() -> void:
	var p := planeta_com("camadas")
	if p < 0:
		return
	var atual := camadas(p)
	var anunciada: int = _camadas_anunciadas.get(p, 0)
	if atual > anunciada:
		_camadas_anunciadas[p] = atual
		camada_alcancada.emit(p, atual - 1)
	elif atual < anunciada:   # depois do rebirth
		_camadas_anunciadas[p] = atual


# ---------- Lua: fragmentos que quicam ----------

func _sortear_intervalo() -> float:
	var p := planeta_com("fragmentos")
	if p < 0:
		return INF
	var c := config(p)
	return _rng.randf_range(float(c["intervalo_min"]), float(c["intervalo_max"]))


func _tick_fragmentos(delta: float) -> void:
	for id in _fragmentos.keys():
		_fragmentos[id] -= delta
		if _fragmentos[id] <= 0.0:
			_fragmentos.erase(id)
	var p := planeta_com("fragmentos")
	if p < 0 or _jogo.planeta_atual != p or _jogo.viajando:
		_fragmentos.clear()   # saiu da Lua: os fragmentos que estavam quicando somem
		return   # só aparecem com você lá
	_proximo_fragmento -= delta
	if _proximo_fragmento <= 0.0:
		_proximo_fragmento = _sortear_intervalo()
		var id := _proximo_id
		_proximo_id += 1
		_fragmentos[id] = float(config(p)["vida_segundos"])
		fragmento_surgiu.emit(id)


func vida_fragmento() -> float:
	var p := planeta_com("fragmentos")
	return float(config(p)["vida_segundos"]) if p >= 0 else 0.0


## Toque num fragmento: retorna quantas barras ganhou (0 se já tinha sumido).
func coletar_fragmento(id: int) -> float:
	var p := planeta_com("fragmentos")
	if p < 0 or not _fragmentos.has(id):
		return 0.0
	_fragmentos.erase(id)
	var c := config(p)
	var ganho: float = max(float(c["barras_minimas"]), _jogo.barras_por_segundo(p) * float(c["segundos_de_barras"]))
	_jogo.barras[p] += ganho
	return ganho


# ---------- Marte: tempestades ----------

## "limpo", "aviso" (tempestade chegando) ou "tempestade".
func estado_tempestade(p: int) -> String:
	if p < 0 or p >= _jogo.desbloqueados:
		return "limpo"
	var c := config(p)
	var ciclo := float(c["ciclo_segundos"])
	var inicio := ciclo - float(c["duracao_segundos"])
	var fase := fmod(tempo, ciclo)
	if fase >= inicio:
		return "tempestade"
	if fase >= inicio - float(c["aviso_segundos"]):
		return "aviso"
	return "limpo"


## Segundos até a próxima tempestade começar (se limpo/aviso) ou acabar (se tempestade).
func segundos_tempestade(p: int) -> float:
	var c := config(p)
	var ciclo := float(c["ciclo_segundos"])
	var fase := fmod(tempo, ciclo)
	var inicio := ciclo - float(c["duracao_segundos"])
	return ciclo - fase if fase >= inicio else inicio - fase


func escudo_ativo() -> bool:
	return tempo < _escudo_ate


func tempestade_ativa_em(p: int) -> bool:
	return estado_tempestade(p) == "tempestade" and not escudo_ativo()


func pode_ativar_escudo() -> bool:
	var p := planeta_com("tempestade")
	return p >= 0 and _jogo.planeta_atual == p and not escudo_ativo() \
		and estado_tempestade(p) in ["aviso", "tempestade"]


## O escudo dura até o fim da tempestade atual (ou da que está chegando).
func ativar_escudo() -> bool:
	if not pode_ativar_escudo():
		return false
	var ciclo := float(config(planeta_com("tempestade"))["ciclo_segundos"])
	_escudo_ate = tempo + (ciclo - fmod(tempo, ciclo))
	return true


func _tick_tempestade() -> void:
	var p := planeta_com("tempestade")
	var estado := estado_tempestade(p)
	if estado != _estado_tempestade:
		_estado_tempestade = estado
		tempestade_mudou.emit(estado)
