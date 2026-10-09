## Formata números grandes de um jeito curto: 1.234.567 vira "1,23M".
class_name Formatar
extends RefCounted

const SUFIXOS := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
const LETRAS := "abcdefghijklmnopqrstuvwxyz"


static func numero(valor: float) -> String:
	if valor < 0.0:
		return "-" + numero(-valor)
	if valor < 10.0:
		# Valores pequenos (ex.: 0,2 barras/s) precisam de uma casa decimal.
		return _virgula("%.1f" % (floor(valor * 10.0) / 10.0)).trim_suffix(",0")
	if valor < 1000.0:
		return str(int(floor(valor)))
	var grupo := int(floor(log(valor) / log(1000.0)))
	var reduzido := valor / pow(1000.0, grupo)
	if reduzido >= 999.995:   # evita "1000,00K"
		grupo += 1
		reduzido /= 1000.0
	return _virgula("%.2f" % reduzido) + sufixo(grupo)


## Depois de "Dc" (10^33) vêm "aa", "ab", "ac"...
static func sufixo(grupo: int) -> String:
	if grupo < SUFIXOS.size():
		return SUFIXOS[grupo]
	var n := grupo - SUFIXOS.size()
	return LETRAS[(n / 26) % 26] + LETRAS[n % 26]


static func _virgula(texto: String) -> String:
	return texto.replace(".", ",")
