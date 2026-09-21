# Dashboard Operativo BHS – AIFA

Prototipo funcional de un **sistema de indicadores operativos para el monitoreo del desempeño en el Sistema de Manejo de Equipaje (BHS) del Aeropuerto Internacional Felipe Ángeles (AIFA)**.

Proyecto de residencia profesional. El tablero está orientado al monitoreo, análisis y seguimiento de alarmas e incidencias operativas del BHS.

> **DATOS DEMO — NO REPRESENTAN EL DESEMPEÑO REAL DEL AIFA.**
> Los registros precargados son simulados y sirven únicamente para demostrar el funcionamiento del prototipo. Los umbrales, severidades y clasificaciones incluidos son valores DEMO y **no constituyen criterios oficiales del BHS**.

---

## Cómo usarlo

1. Descarga `dashboard_bhs_aifa.html`.
2. Ábrelo con doble clic en cualquier navegador moderno (Chrome, Edge o Firefox).
3. No requiere instalación, servidor ni conexión a internet.

### Cargar datos reales

`Datos` → **Cargar archivo CSV** (o arrastra el archivo a la zona de carga).

- Formato admitido: **CSV** con separador coma, punto y coma o tabulador; codificación UTF-8 recomendada.
- Los archivos `.xlsx` no pueden leerse sin librerías externas: en Excel usa *Archivo → Guardar como → CSV UTF-8* y carga el resultado.
- El botón **Descargar plantilla CSV** genera un archivo con los encabezados que el normalizador reconoce.
- Columnas obligatorias: `Fecha` y `Hora de activación`. El resto son opcionales y se completan como *no identificado* cuando faltan.
- Si faltan columnas obligatorias, el tablero lo indica y no sustituye los datos cargados.
- **Restaurar datos DEMO** devuelve el conjunto simulado en cualquier momento.

### Filtros

Barra superior: fecha inicial, fecha final, hora inicial, hora final, coordinador en turno, tipo de alarma y estado de operación. En **Filtros adicionales**: turno, nivel, área/subcategoría, severidad, status y clasificación NAT/IOC.

Los filtros se combinan entre sí. **Aplicar filtros** actualiza KPIs, gráficas, tablas, semáforos y comparaciones temporales; **Limpiar filtros** restablece el rango completo.

**Exportar datos filtrados** genera un CSV únicamente con los registros que cumplen los filtros activos, con la fecha y hora de generación incluidas como metadatos.

---

## Secciones

| Sección | Contenido |
|---|---|
| **Resumen** | Los cuatro KPIs principales, frecuencia por tipo de alarma, distribución por severidad y comparación temporal. |
| **Operación** | Tiempos de paro NAT/IOC, frecuencia de paros por día/semana/mes, comportamiento por turno y área, y tabla de alarmas activas. |
| **Desempeño** | Tiempo de respuesta en cascada Nivel → Área/Subcategoría → Tipo de alarma, histograma de tiempos, cumplimiento diario y fichas técnicas de cada indicador. |
| **Incidencias** | Totales por tipo, fecha, turno, nivel, área y severidad, con tabla detallada. |
| **Tendencias** | Evolución diaria, semanal y mensual del indicador seleccionado, con desglose por turno. |
| **Datos** | Carga de CSV, indicadores de calidad de datos, registro histórico completo y documentación de integración. |

El botón **Resumen para reporte** abre una vista condensada para reportes técnicos, con opción de imprimir o exportar.

---

## Indicadores implementados

| KPI | Fórmula | Unidad |
|---|---|---|
| **Frecuencia de alarmas** | Conteo de activaciones de la alarma seleccionada en el periodo | Activaciones |
| **Tiempo de paro total** | Suma de la duración de los eventos clasificados NAT o IOC | Minutos |
| **Tiempo de respuesta** | Hora de restablecimiento − hora de activación | Minutos |
| **Cumplimiento operativo** | Registros resueltos dentro del objetivo / registros resueltos × 100 | Porcentaje |

Cada indicador incluye su ficha técnica completa (descripción, fórmula, unidad, fuente, campos, umbral e interpretación) dentro de la sección **Desempeño**.

### Reglas de cálculo

- **Alarmas activas.** Un registro con hora de activación y sin hora de restablecimiento se marca como `ALARMA ACTIVA`. No se le calcula tiempo de respuesta ni tiempo de paro, y queda fuera de la base del cumplimiento. Nunca se inventa una hora de restablecimiento; el tiempo transcurrido se muestra solo como referencia de seguimiento.
- **Cruce de medianoche.** Si la hora de restablecimiento es anterior a la de activación se asume cruce de medianoche y se suman 24 h. Si la duración resultante supera 24 h, el registro se marca como dato sospechoso.
- **Turnos de 12 horas.** `07:00 – 19:00` y `19:00 – 07:00`, determinados automáticamente a partir de la hora de activación. Los eventos anteriores a las 07:00 se contabilizan en la *fecha operativa* del día anterior (configurable).
- **Comparación temporal.** El tablero muestra valor actual, valor anterior, diferencia absoluta y variación porcentual. **No califica automáticamente una variación como mejora o deterioro**: la interpretación depende de la naturaleza de cada indicador.
- **Áreas.** No se promedian tiempos entre áreas distintas; cada área se presenta por separado.

---

## Definiciones pendientes

El prototipo marca explícitamente como `PENDIENTE DE DEFINICIÓN CON BASE EN DOCUMENTACIÓN TÉCNICA` todo aquello que requiere documentación oficial que aún no se ha entregado:

- Nomenclatura oficial de alarmas del BHS.
- Definición formal de **NAT** e **IOC**.
- Definición operativa de *paro total* frente a la duración del evento.
- Descripción técnica de los niveles `-4`, `0.0`, `5.25` y `10.50`.
- Catálogo oficial de áreas y subcategorías por nivel.
- Criterios oficiales de severidad y estado de operación.
- Umbrales oficiales de tiempo de respuesta, tiempo de paro y cumplimiento.
- Confirmación de la regla de fecha operativa para el turno nocturno.
- Estructura definitiva de las columnas del extracto de SQL MV.

Las categorías `PEC JAM`, `PARCEL TOO LONG`, `MOTOR DRIVE` y `FALLA ASÍ` son **ejemplos iniciales**, no nomenclatura oficial.

---

## Arquitectura

Un único archivo HTML autocontenido: HTML5, CSS3 y JavaScript puro. Sin frameworks, sin CDN y sin dependencias externas. Las gráficas se dibujan con **Canvas 2D nativo** (barras, barras agrupadas, barras horizontales, líneas con relleno de área y dona), con tooltips y redibujo al cambiar el tamaño de la ventana.

El script está dividido en 13 bloques comentados:

```
 1. Configuración          8. Motor de gráficas (Canvas)
 2. Utilidades             9. Tablas interactivas
 3. Lógica de turnos      10. Render de indicadores y secciones
 4. Datos DEMO            11. CSV, exportación y conexión futura
 5. Normalización         12. Resumen para reporte técnico
 6. Estado y filtrado     13. Navegación, eventos e inicialización
 7. Cálculo de indicadores
```

### Estructura de datos

```js
{
  id, fecha, fechaOperativa, horaActivacion, horaRestablecimiento,
  turno, coordinador, tipoAlarma, categoria, nivel, area, clasificacion,
  status, estadoOperacion, severidad, descripcion,
  tiempoParo, tiempoRespuesta, activa, errores, avisos, completo
}
```

No se asume definitiva. La función `normalizarConjunto()` traduce cualquier encabezado real al modelo interno mediante `MAPEO_COLUMNAS`, que acepta una lista de alias por campo. Los datos DEMO pasan por el mismo normalizador que un CSV cargado, de modo que la ruta de ingesta se ejercita siempre igual.

### Dónde editar

Todo lo que depende de documentación del BHS está centralizado al inicio del script:

| Constante | Contenido |
|---|---|
| `NOMENCLATURA` | Alarmas, categorías, niveles, áreas, severidades, status, coordinadores |
| `UMBRALES` | Valores de semáforo (DEMO) |
| `FORMULAS` | Tiempo de paro, criterio de cumplimiento y regla de exclusión |
| `TURNOS` | Horas de corte, etiquetas y regla de fecha operativa |
| `MAPEO_COLUMNAS` | Alias de encabezados aceptados al cargar CSV |
| `FICHAS_INDICADORES` | Documentación de cada KPI |
| `PENDIENTES` | Lista de definiciones por confirmar |

---

## Integración futura con SQL MV / SCADA

El archivo **no se conecta a ninguna base de datos** y **no contiene usuarios, contraseñas, direcciones IP ni cadenas de conexión**.

El esquema previsto es:

```
Navegador (este archivo)
     │  fetch GET /api/alarmas?desde=AAAA-MM-DD&hasta=AAAA-MM-DD
     ▼
Backend propio (Node / .NET / Python) — credenciales en variables de entorno
     │  consulta parametrizada de solo lectura
     ▼
SQL Server «SQL MV» con registros provenientes de SACADA/SCADA
```

El punto de entrada es la función `cargarDatosDesdeAPI()`, documentada en el bloque 11. El backend puede devolver los nombres de columna originales: el normalizador los traduce igual que a un CSV.

---

## Verificación

La lógica de cálculo se validó con un banco de 96 pruebas automatizadas que cubre parseo de fechas y horas en varios formatos, cruce de medianoche, asignación de turnos, normalización y validación de registros, filtros combinados, agregación temporal, escalas de gráfica, semáforos, variaciones y un ciclo completo de exportación y reimportación de CSV.
