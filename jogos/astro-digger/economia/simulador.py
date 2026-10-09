"""
Simulador de economia do Astro Digger.

Lê codigo/data/economia.json e simula um jogador "comprando com bom senso" pra medir
quanto tempo leva pra construir cada nave e quanta Poeira Estelar rende o
primeiro rebirth.

Uso:
    python simulador.py                  # jogador contínuo + jogador típico
    python simulador.py --bonus 1.5      # simula com bônus global de produção (ex.: árvore após rebirth)

É uma ESTIMATIVA. Serve pra comparar versões da economia, não pra prever o
comportamento exato de cada jogador.
"""
import argparse
import json
import math
import sys
from pathlib import Path

# O arquivo mora dentro do projeto Godot: o jogo e o simulador leem exatamente os mesmos números.
CAMINHO_CONFIG = Path(__file__).resolve().parent.parent / "codigo" / "data" / "economia.json"
CONFIG = json.loads(CAMINHO_CONFIG.read_text(encoding="utf-8"))
G = CONFIG["global"]
PLANETAS = CONFIG["planetas"]
IDX = {p["id"]: i for i, p in enumerate(PLANETAS)}


def marcos(nivel):
    """Multiplicador dos marcos de nível (x2 em 10, 25, 50...)."""
    n = sum(1 for m in G["marcos_de_nivel"] if nivel >= m)
    return G["multiplicador_por_marco"] ** n


def prod_mina(mina, nivel):
    return mina["producao_base"] * nivel * marcos(nivel) if nivel > 0 else 0.0


def custo(item, nivel):
    """Custo pra ir do nível atual pro próximo."""
    return item["custo_base"] * item["crescimento"] ** nivel


def rate_ref(ref, nivel):
    return ref["barras_por_segundo_base"] * nivel * marcos(nivel) if nivel > 0 else 0.0


class Jogo:
    def __init__(self, bonus=1.0):
        self.bonus = bonus
        self.t = 0.0
        self.creditos = 10.0
        self.creditos_run = 0.0
        self.minas = [[0] * len(p["minas"]) for p in PLANETAS]
        self.ref = [0] * len(PLANETAS)
        self.barras = [0.0] * len(PLANETAS)
        self.atual = 0                        # planeta mais avançado (onde o jogador fica)
        self.chegadas = {"terra": 0.0}
        self.tela = 0.0                       # segundos com o jogo aberto
        self.tela_chegada = {}

    # ---------- produção ----------
    def mult(self, p, online):
        pres = G["bonus_presenca"] if (online and p == self.atual) else 1.0
        return pres * self.bonus

    def renda(self, online=True):
        return sum(
            sum(prod_mina(m, lv) for m, lv in zip(PLANETAS[p]["minas"], self.minas[p])) * self.mult(p, online)
            for p in range(self.atual + 1)
        )

    def taxa_barras(self, p, online=True):
        return rate_ref(PLANETAS[p]["refinaria"], self.ref[p]) * self.mult(p, online)

    def avancar(self, dt, online=True, eficiencia=1.0):
        r = self.renda(online) * eficiencia
        self.creditos += r * dt
        self.creditos_run += r * dt
        for p in range(self.atual + 1):
            self.barras[p] += self.taxa_barras(p, online) * eficiencia * dt

    # ---------- nave ----------
    def requisitos(self):
        return {IDX[k]: v for k, v in PLANETAS[self.atual]["nave"]["custo_total_barras"].items()}

    def tenta_lancar(self):
        req = self.requisitos()
        destino = PLANETAS[self.atual]["nave"]["destino"]
        pronta = all(self.barras[p] >= v for p, v in req.items())
        if destino not in IDX:
            # Último planeta do conteúdo atual: só registra quando a nave ficaria pronta.
            if pronta and destino not in self.chegadas:
                self.chegadas[destino] = self.t
                self.tela_chegada[destino] = self.tela
            return False
        if pronta:
            for p, v in req.items():
                self.barras[p] -= v
            self.atual += 1
            self.chegadas[PLANETAS[self.atual]['id']] = self.t
            self.tela_chegada[PLANETAS[self.atual]['id']] = self.tela
            return True
        return False

    # ---------- decisão de compra ----------
    def opcoes(self):
        """Retorna (custo, acao) da melhor mina e da refinaria gargalo; o jogador compra a mais barata."""
        melhor = None
        for p in range(self.atual + 1):
            minas = PLANETAS[p]["minas"]
            for i, m in enumerate(minas):
                lv = self.minas[p][i]
                if lv == 0 and i > 0 and self.minas[p][i - 1] == 0:
                    continue                        # só libera a mina seguinte depois da anterior
                c = custo(m, lv)
                ganho = (prod_mina(m, lv + 1) - prod_mina(m, lv)) * self.mult(p, True)
                payback = c / ganho
                if melhor is None or payback < melhor[0]:
                    melhor = (payback, c, ("mina", p, i))
        opcoes = [(melhor[1], melhor[2])]
        req = self.requisitos()
        gargalo, pior = None, -1
        for p, v in req.items():
            falta = max(0.0, v - self.barras[p])
            if falta <= 0:
                continue
            taxa = self.taxa_barras(p)
            eta = math.inf if taxa == 0 else falta / taxa
            if eta > pior:
                gargalo, pior = p, eta
        if gargalo is not None:
            opcoes.append((custo(PLANETAS[gargalo]["refinaria"], self.ref[gargalo]), ("ref", gargalo)))
        return min(opcoes, key=lambda o: o[0])

    def comprar_o_possivel(self):
        while True:
            c, acao = self.opcoes()
            if c > self.creditos:
                return c
            self.creditos -= c
            if acao[0] == "mina":
                self.minas[acao[1]][acao[2]] += 1
            else:
                self.ref[acao[1]] += 1

    def jogar_online(self, duracao):
        fim = self.t + duracao
        while self.t < fim:
            prox = self.comprar_o_possivel()
            self.tenta_lancar()
            r = self.renda()
            espera = (prox - self.creditos) / r if r > 0 else 60
            dt = max(1.0, min(espera, 60.0, fim - self.t))
            self.avancar(dt)
            self.t += dt
            self.tela += dt

    def ficar_offline(self, duracao):
        efetivo = min(duracao, G["offline_limite_horas"] * 3600)
        self.avancar(efetivo, online=False, eficiencia=G["offline_eficiencia"])
        self.t += duracao
        self.tenta_lancar()

    def poeira(self):
        rb = CONFIG["rebirth"]
        return math.floor((self.creditos_run / rb["divisor"]) ** rb["expoente"] + 1e-9)   # igual ao jogo


def fmt(seg):
    if seg < 3600:
        return f"{seg / 60:.0f} min"
    if seg < 86400:
        return f"{seg / 3600:.1f} h"
    return f"{seg / 86400:.1f} dias"


def rotulo(pid):
    return f"Chegou em {pid}" if pid in IDX else "Nave de Marte pronta (próximo planeta)"


def jogador_continuo(bonus):
    j = Jogo(bonus)
    while j.atual < IDX["marte"] and j.t < 30 * 86400:
        j.jogar_online(60)
    t_marte = j.t
    marcas = {}
    for horas in (0, 24, 72):
        alvo = t_marte + horas * 3600
        if j.t < alvo:
            j.jogar_online(alvo - j.t)
        marcas[horas] = j.poeira()
    print("\n=== Jogador contínuo (sempre online, tempo de jogo) ===")
    for pid, t in j.chegadas.items():
        if pid != "terra":
            print(f"  {rotulo(pid)}: {fmt(t)}")
    for h, p in marcas.items():
        print(f"  Poeira se fizer rebirth {h:2d}h depois de chegar em Marte: {p}")


PRIMEIRA_SESSAO_MIN = 35   # a 1ª vez que a pessoa abre o jogo é a sessão mais longa
SESSOES = [  # (hora de início, minutos online) num dia típico
    (8.0, 8), (12.5, 8), (18.0, 8), (21.0, 8), (23.0, 8),
]


def jogador_tipico(bonus, dias=14):
    j = Jogo(bonus)
    poeira_por_dia = []
    for dia in range(dias):
        for k, (hora, mins) in enumerate(SESSOES):
            inicio = dia * 86400 + hora * 3600
            if j.t < inicio:
                j.ficar_offline(inicio - j.t)
            dur = (PRIMEIRA_SESSAO_MIN if dia == 0 and k == 0 else mins) * 60
            j.jogar_online(dur)
        poeira_por_dia.append(j.poeira() if j.atual >= IDX["marte"] else None)
    print(f"\n=== Jogador típico (1ª sessão de {PRIMEIRA_SESSAO_MIN} min, depois 5 sessões de 8 min/dia) ===")
    for pid, t in j.chegadas.items():
        if pid != "terra":
            print(f"  {rotulo(pid)}: dia {t / 86400 + 1:.1f} ({fmt(j.tela_chegada[pid])} de tela)")
    print("  Poeira se fizer rebirth no fim do dia:")
    print("   " + "  ".join(f"d{d + 1}={p}" for d, p in enumerate(poeira_por_dia) if p is not None))
    return j


BONUS_POR_POEIRA = 0.1   # aproximação da árvore: ~10 Poeira bem gastas ≈ 2x mais forte


def jogador_com_rebirth(dias=21, minimo=8):
    """Jogador típico que faz rebirth assim que pode (nave de Marte pronta) e a Poeira nova vale a pena."""
    poeira_total = 0
    j = Jogo(1.0)
    inicio_exp = 0.0
    eventos = []
    for dia in range(dias):
        for k, (hora, mins) in enumerate(SESSOES):
            inicio = dia * 86400 + hora * 3600
            if j.t < inicio:
                j.ficar_offline(inicio - j.t)
            dur = (PRIMEIRA_SESSAO_MIN if dia == 0 and k == 0 else mins) * 60
            j.jogar_online(dur)
            if "em_breve" in j.chegadas and j.poeira() >= max(minimo, poeira_total):
                ganho = j.poeira()
                eventos.append((inicio_exp, j.chegadas["em_breve"], j.t, ganho))
                poeira_total += ganho
                t, tela = j.t, j.tela
                j = Jogo(1.0 + BONUS_POR_POEIRA * poeira_total)
                j.t, j.tela = t, tela
                inicio_exp = t
    print(f"\n=== Jogador típico com rebirth (libera com a nave de Marte pronta; bônus ≈ +{BONUS_POR_POEIRA:.0%} por Poeira) ===")
    for n, (ini_e, nave, rb, g) in enumerate(eventos, 1):
        print(f"  Expedição {n}: começou dia {ini_e / 86400 + 1:.1f}, nave de Marte em {fmt(nave - ini_e)}, "
              f"rebirth dia {rb / 86400 + 1:.1f} (+{g} Poeira)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")   # acentos no terminal do Windows
    ap = argparse.ArgumentParser()
    ap.add_argument("--bonus", type=float, default=1.0, help="multiplicador global de produção")
    a = ap.parse_args()
    jogador_continuo(a.bonus)
    jogador_tipico(a.bonus)
    jogador_com_rebirth()
