"""Quita de las listas públicas los canales de TV de paga (sin licencia para retransmisión gratuita).
Uso: python3 tools/filtrar_listas.py listas/*.m3u"""
import re, sys
PAGA = re.compile(r"\b(a&e|amc|axn|autentic|cine ?sony|sony|cinelatino|cinecanal|cinemax|hbo|max prime|claro (cinema|sports|musica)|cartoon ?network|cartoonito|comedy central|de pel[ií]cula|discovery|disney|e!|espn\w*|fx|filmex|food network|fox sports|golden|multipremier|space|tnt|universal|warner|studio|star channel|paramount network|nick(elodeon)?|history|nat ?geo|national geographic|lifetime|tlc|hgtv|mtv|vh1|telehit|bandamax|unicable|tl ?novelas|distrito comedia|win sports|dazn|bein|sky|tudn|galavision|cnn|tyc sports|tnt sports|directv|dsports|gol ?tv|willax|movistar|cine ?premium|cine ?latino|pasiones|tooncast|boomerang|adult swim|syfy|usa network|showtime|starz|epix|mgm|sundance|ifc|bravo|oxygen|investigation discovery|animal planet|travel channel|cooking channel|velocity|bbc|hallmark|sec network|acc network|nfl network|nba tv|mlb network|nhl network|big ten|golf channel|tennis channel|fight network)\b", re.I)
LIBRE = re.compile(r"pluto|samsung tv plus|vix|tubi|plex|xumo|roku|stirr|runtime|canela", re.I)
def es_paga(nombre): return bool(PAGA.search(nombre)) and not LIBRE.search(nombre)
for ruta in sys.argv[1:]:
    lineas = open(ruta, encoding="utf-8").read().splitlines()
    out, quitados, i = [lineas[0]], 0, 1
    while i < len(lineas):
        l = lineas[i]
        if l.startswith("#EXTINF"):
            bloque = [l]; i += 1
            while i < len(lineas) and lineas[i].startswith("#") and not lineas[i].startswith("#EXTINF"):
                bloque.append(lineas[i]); i += 1
            if i < len(lineas) and not lineas[i].startswith("#"):
                bloque.append(lineas[i]); i += 1
            if es_paga(l.split(",", 1)[-1]): quitados += 1
            else: out += bloque
        else:
            i += 1
    open(ruta, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(f"{ruta}: {quitados} canales de paga quitados, {sum(1 for x in out if x.startswith('#EXTINF'))} quedan")
