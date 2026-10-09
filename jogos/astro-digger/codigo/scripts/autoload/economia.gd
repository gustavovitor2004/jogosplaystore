## Economia: lê data/economia.json e faz todas as contas de balanceamento.
##
## Nenhum número de balanceamento fica no código. Pra mudar preço, produção
## ou custo de nave, edite o JSON e rode o simulador (economia/simulador.py).
## As fórmulas aqui são as mesmas do simulador, e o teste
## tests/test_economia.gd garante que continuam iguais.
extends Node

const CAMINHO := "res://data/economia.json"

var dados: Dictionary = {}
var planetas: Array = []
var global: Dictionary = {}


func _init() -> void:
	carregar()


func carregar() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("economia.json inválido ou ausente: %s" % CAMINHO)
		return
	dados = parsed
	planetas = dados["planetas"]
	global = dados["global"]


# ---------- marcos de nível (x2 nos níveis 10, 25, 50...) ----------

func multiplicador_marcos(nivel: int) -> float:
	var n := 0
	for marco in global["marcos_de_nivel"]:
		if nivel >= int(marco):
			n += 1
	return pow(float(global["multiplicador_por_marco"]), n)


## Próximo nível que dobra a produção, ou -1 se já passou de todos.
func proximo_marco(nivel: int) -> int:
	for marco in global["marcos_de_nivel"]:
		if nivel < int(marco):
			return int(marco)
	return -1


# ---------- produção ----------

func mina(p: int, i: int) -> Dictionary:
	return planetas[p]["minas"][i]


func refinaria(p: int) -> Dictionary:
	return planetas[p]["refinaria"]


func producao_mina(p: int, i: int, nivel: int) -> float:
	if nivel <= 0:
		return 0.0
	return float(mina(p, i)["producao_base"]) * nivel * multiplicador_marcos(nivel)


func barras_refinaria(p: int, nivel: int) -> float:
	if nivel <= 0:
		return 0.0
	return float(refinaria(p)["barras_por_segundo_base"]) * nivel * multiplicador_marcos(nivel)


# ---------- custos (servem pra mina e refinaria) ----------

## Custo de subir `n` níveis a partir de `nivel`.
## É a soma de uma progressão geométrica: cada nível custa `crescimento` vezes o anterior.
func custo_n(item: Dictionary, nivel: int, n: int) -> float:
	var g := float(item["crescimento"])
	var primeiro := float(item["custo_base"]) * pow(g, nivel)
	return primeiro * (pow(g, n) - 1.0) / (g - 1.0)


## Quantos níveis dá pra comprar com `dinheiro` (botão "MÁX").
func max_compravel(item: Dictionary, nivel: int, dinheiro: float) -> int:
	var g := float(item["crescimento"])
	var primeiro := float(item["custo_base"]) * pow(g, nivel)
	if dinheiro < primeiro:
		return 0
	var n := int(floor(log(dinheiro * (g - 1.0) / primeiro + 1.0) / log(g)))
	# Corrige arredondamento de ponto flutuante na borda.
	while n > 0 and custo_n(item, nivel, n) > dinheiro:
		n -= 1
	return n


# ---------- naves ----------

## Índice do planeta de destino da nave do planeta `p`, ou -1 se ainda não existe ("em breve").
func destino_nave(p: int) -> int:
	return indice_planeta(planetas[p]["nave"]["destino"])


## {índice_do_planeta: barras necessárias}
func requisitos_nave(p: int) -> Dictionary:
	var req := {}
	var custos: Dictionary = planetas[p]["nave"]["custo_total_barras"]
	for id in custos:
		req[indice_planeta(id)] = float(custos[id])
	return req


func indice_planeta(id: String) -> int:
	for i in planetas.size():
		if planetas[i]["id"] == id:
			return i
	return -1
