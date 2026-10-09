## Jogo: guarda o estado do jogador (créditos, níveis, barras, planetas) e as ações
## (comprar, lançar nave, viajar). A tela só lê daqui e chama as ações.
##
## PROTÓTIPO: o save ainda é um JSON simples e o tempo offline usa o relógio do
## aparelho. O módulo Security Foundation vai trocar isso por save criptografado
## com HMAC e por horário do servidor. Os pontos de troca estão marcados com
## "SECURITY FOUNDATION".
extends Node

signal estado_mudou
signal viagem_comecou(de: int, para: int)
signal planeta_desbloqueado(p: int)

const VERSAO_SAVE := 1
const CAMINHO_SAVE := "user://save.json"
const INTERVALO_AUTOSAVE := 10.0
## Duração fixa da animação de viagem. Não dá pra pular porque é um item cosmético.
const DURACAO_VIAGEM := 1.0

var creditos := 0.0
var minas: Array = []          # minas[planeta][mina] = nível
var refinarias: Array = []     # refinarias[planeta] = nível
var barras: Array = []         # barras[planeta] = estoque
var naves_prontas: Array = []  # naves_prontas[planeta] = true depois de lançada/concluída
var desbloqueados := 1         # quantos planetas já foram liberados (Terra = 1)
var planeta_atual := 0         # onde o jogador está (ganha o bônus de presença)
var viajando := false
var ganho_offline := 0.0       # pra tela mostrar "enquanto você estava fora..."
var caminho_save := CAMINHO_SAVE  # os testes trocam por um arquivo próprio

var _tempo_autosave := 0.0
var _pausado_em := 0.0


func _ready() -> void:
	novo_jogo()
	carregar()


func _process(delta: float) -> void:
	produzir(delta, true, 1.0)
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


func novo_jogo() -> void:
	creditos = float(Economia.global.get("creditos_iniciais", 10))
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
	desbloqueados = 1
	planeta_atual = 0
	viajando = false
	ganho_offline = 0.0


# ---------- produção ----------

func multiplicador_planeta(p: int, online := true) -> float:
	if online and p == planeta_atual:
		return float(Economia.global["bonus_presenca"])
	return 1.0


func producao_mina(p: int, i: int, online := true) -> float:
	return Economia.producao_mina(p, i, minas[p][i]) * multiplicador_planeta(p, online)


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
	return Economia.barras_refinaria(p, refinarias[p]) * multiplicador_planeta(p, online)


## Roda a produção de todos os planetas liberados por `segundos`.
func produzir(segundos: float, online: bool, eficiencia: float) -> void:
	creditos += renda_total(online) * eficiencia * segundos
	for p in desbloqueados:
		barras[p] += barras_por_segundo(p, online) * eficiencia * segundos


func valor_toque() -> float:
	var segundos := float(Economia.global["toque_segundos_de_producao"])
	return max(1.0, renda_planeta(planeta_atual) * segundos)


func minerar_toque() -> void:
	creditos += valor_toque()


# ---------- compras ----------

func mina_liberada(p: int, i: int) -> bool:
	return i == 0 or minas[p][i - 1] > 0


## Calcula quanto custa comprar no modo escolhido (1, 10 ou -1 = máximo).
## Retorna {"n": níveis, "custo": créditos}.
func orcamento(item: Dictionary, nivel: int, modo: int) -> Dictionary:
	var n := modo
	if modo <= 0:
		n = max(1, Economia.max_compravel(item, nivel, creditos))
	return {"n": n, "custo": Economia.custo_n(item, nivel, n)}


func comprar_mina(p: int, i: int, modo: int) -> bool:
	if p >= desbloqueados or not mina_liberada(p, i):
		return false
	var o := orcamento(Economia.mina(p, i), minas[p][i], modo)
	if o["custo"] > creditos:
		return false
	creditos -= o["custo"]
	minas[p][i] += o["n"]
	estado_mudou.emit()
	return true


func comprar_refinaria(p: int, modo: int) -> bool:
	if p >= desbloqueados:
		return false
	var o := orcamento(Economia.refinaria(p), refinarias[p], modo)
	if o["custo"] > creditos:
		return false
	creditos -= o["custo"]
	refinarias[p] += o["n"]
	estado_mudou.emit()
	return true


# ---------- nave e viagem ----------

## De 0 a 1: quanto da nave já dá pra montar com as barras em estoque.
func progresso_nave(p: int) -> float:
	var req := Economia.requisitos_nave(p)
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
	var req := Economia.requisitos_nave(p)
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

## Aplica os ganhos de quando o app estava fechado (com limite e eficiência).
func aplicar_offline(segundos: float) -> void:
	if segundos <= 0.0:
		return
	var limite := float(Economia.global["offline_limite_horas"]) * 3600.0
	var efetivo: float = min(segundos, limite)
	var antes := creditos
	produzir(efetivo, false, float(Economia.global["offline_eficiencia"]))
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
		"minas": minas,
		"refinarias": refinarias,
		"barras": barras,
		"naves_prontas": naves_prontas,
		"desbloqueados": desbloqueados,
		"planeta_atual": planeta_atual,
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
	if typeof(dados) != TYPE_DICTIONARY or int(dados.get("versao", 0)) != VERSAO_SAVE:
		# Save corrompido ou de outra versão: começa do zero sem travar o jogo.
		push_warning("Save inválido, começando um jogo novo.")
		return
	_aplicar_save(dados)
	aplicar_offline(_agora() - float(dados.get("salvo_em", _agora())))


## Copia os valores do save com cuidado: se o jogo ganhou planetas ou minas novas
## numa atualização, os que não existiam no save ficam no valor inicial.
func _aplicar_save(dados: Dictionary) -> void:
	creditos = max(0.0, float(dados.get("creditos", creditos)))
	var minas_salvas: Array = dados.get("minas", [])
	for p in min(minas.size(), minas_salvas.size()):
		for i in min(minas[p].size(), minas_salvas[p].size()):
			minas[p][i] = max(0, int(minas_salvas[p][i]))
	_copiar_lista(refinarias, dados.get("refinarias", []), func(v): return max(0, int(v)))
	_copiar_lista(barras, dados.get("barras", []), func(v): return max(0.0, float(v)))
	_copiar_lista(naves_prontas, dados.get("naves_prontas", []), func(v): return bool(v))
	desbloqueados = clamp(int(dados.get("desbloqueados", 1)), 1, Economia.planetas.size())
	planeta_atual = clamp(int(dados.get("planeta_atual", 0)), 0, desbloqueados - 1)


func _copiar_lista(destino: Array, origem: Array, converter: Callable) -> void:
	for k in min(destino.size(), origem.size()):
		destino[k] = converter.call(origem[k])


## Só pra testes: apaga o save e recomeça.
func resetar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(caminho_save)
	novo_jogo()
	estado_mudou.emit()
