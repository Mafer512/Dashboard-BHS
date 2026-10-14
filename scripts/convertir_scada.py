"""Convierte Worksheet1 al JSON incrustado del dashboard, sin dependencias."""
import argparse
from collections import Counter
from datetime import datetime, timedelta
import json
import os
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
COLUMNAS = ["Date Time", "Priority", "Description", "Tag", "Status", "Active Time/Date"]
EPOCA = datetime(1899, 12, 30)


def fecha_excel(valor, epoca):
    """Interpreta hora local, sin conversiones de zona horaria."""
    texto = str(valor).strip()
    patron = r"(\d{2})/(\d{2})/(\d{4}) (\d{1,2}):(\d{2}):(\d{2})\s+([ap])\.\s*m\."
    m = re.fullmatch(patron, texto, re.I)
    if m:
        dia, mes, anio, hora, minuto, segundo = map(int, m.groups()[:6])
        if not 1 <= hora <= 12:
            raise ValueError("Hora de 12 horas invalida: " + texto)
        fecha = datetime(anio, mes, dia, hora % 12 + (12 if m[7].lower() == "p" else 0), minuto, segundo)
    else:
        fecha = epoca + timedelta(seconds=round(float(texto) * 86400))
    serial = (fecha - EPOCA).total_seconds() / 86400
    if EPOCA + timedelta(seconds=round(serial * 86400)) != fecha:
        raise ValueError("La conversion no conserva los segundos: " + texto)
    return str(serial)


def leer_excel(archivo):
    with zipfile.ZipFile(archivo) as z:
        libro = ET.fromstring(z.read("xl/workbook.xml"))
        hoja = next((h for h in libro.find("s:sheets", NS) if h.get("name") == "Worksheet1"), None)
        if hoja is None:
            raise ValueError("Falta la hoja Worksheet1")
        rel_id = hoja.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
        relaciones = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        destino = next(r.get("Target") for r in relaciones if r.get("Id") == rel_id)
        ruta = destino.lstrip("/") if destino.startswith("/") else "xl/" + destino
        cadenas = []
        if "xl/sharedStrings.xml" in z.namelist():
            cadenas = ["".join(e.itertext()) for e in ET.fromstring(z.read("xl/sharedStrings.xml"))]
        prop = libro.find("s:workbookPr", NS)
        epoca = datetime(1904, 1, 1) if prop is not None and prop.get("date1904") in ("1", "true") else EPOCA
        filas = []
        for fila in ET.fromstring(z.read(ruta)).find("s:sheetData", NS):
            valores = {}
            for celda in fila:
                columna = re.sub(r"\d", "", celda.get("r"))
                valor = celda.findtext("s:v", "", NS)
                if celda.get("t") == "s":
                    valor = cadenas[int(valor)]
                elif celda.get("t") == "inlineStr":
                    valor = "".join(celda.find("s:is", NS).itertext())
                valores[columna] = valor
            if any(valores.values()):
                filas.append((int(fila.get("r")), valores))
        encabezado = {nombre: col for col, nombre in filas[0][1].items()}
        faltantes = set(COLUMNAS) - encabezado.keys()
        if faltantes:
            raise ValueError("Faltan columnas: " + ", ".join(sorted(faltantes)))
        salida = []
        for numero, valores in filas[1:]:
            registro = {c: valores.get(encabezado[c], "") for c in COLUMNAS}
            if registro["Status"] == "7":
                print("Status 7, fila", numero, ":", registro["Tag"], "| activacion:", registro["Active Time/Date"], "| evento:", registro["Date Time"], "| no se interpreta como cierre")
            for c in ("Date Time", "Active Time/Date"):
                registro[c] = fecha_excel(registro[c], epoca)
            salida.append([registro[c] for c in COLUMNAS])
        return {"columnas": COLUMNAS, "filas": salida}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("entrada", type=Path, help="Excel SCADA o JSON archivado")
    parser.add_argument("--dashboard", type=Path, default=Path(__file__).resolve().parents[1] / "dashboard_bhs_aifa.html")
    parser.add_argument("--demo", action="store_true", help="Identifica como demo la base anterior restaurada")
    args = parser.parse_args()
    archivo = args.entrada.resolve()
    datos = json.loads(archivo.read_text(encoding="utf-8-sig")) if archivo.suffix.lower() == ".json" else leer_excel(archivo)
    if not {"Tag", "Status", "Active Time/Date", "Date Time", "Description"} <= set(datos["columnas"]):
        raise ValueError("JSON sin columnas SCADA requeridas")
    if any(len(f) != len(datos["columnas"]) for f in datos["filas"]):
        raise ValueError("Fila con cantidad de columnas incorrecta")
    meta = {"fuente": "DEMO" if args.demo else "SCADA", "nombreArchivo": archivo.name,
            "rutaArchivo": Path(os.path.relpath(archivo, args.dashboard.resolve().parent)).as_posix(), "columnas": datos["columnas"]}
    contenido = json.dumps(meta, ensure_ascii=False, separators=(",", ":"))[:-1] + ',"filas":[\n'
    contenido += ",\n".join(json.dumps(f, ensure_ascii=False, separators=(",", ":")) for f in datos["filas"]) + "\n]}"
    contenido = contenido.replace("<", "\\u003c")
    original = args.dashboard.read_bytes()
    salto = "\r\n" if b"\r\n" in original else "\n"
    html = original.decode("utf-8").replace("\r\n", "\n")
    patron = r'(<script type="application/json" id="datosScadaDemo">\n)[\s\S]*?(\n</script>)'
    html, cantidad = re.subn(patron, lambda m: m[1] + contenido + m[2], html)
    if cantidad != 1:
        raise ValueError("No se encontro un unico bloque datosScadaDemo")
    args.dashboard.write_bytes(html.replace("\n", salto).encode("utf-8"))
    idx = datos["columnas"].index("Status")
    print("Filas:", len(datos["filas"]), "| Status:", dict(Counter(str(f[idx]) for f in datos["filas"])))
    print("Dashboard actualizado:", args.dashboard)


if __name__ == "__main__":
    main()
