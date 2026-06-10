# Cómo ganar la segunda vuelta — análisis comparado (13 ciudades)

Sitio **estático** (sin servidor) de análisis **comparado** ciudad por ciudad de cara a la 2ª vuelta
2026: dónde se perdió el voto frente a 2022, a qué público hablarle y hacia dónde ir. El landing es
una **tabla comparada ordenable** + **mapa nacional**; cada ciudad abre un detalle con mapas por
comuna/puesto, perfil etario (DANE) y recomendaciones. Pensado para publicarse gratis en GitHub Pages.

> El PDF `Línea gráfica…pdf` y los scripts/insumos pesados NO deben subirse al sitio: súbelo solo
> con index.html, style.css, app.js, data.js, geo.js y la carpeta img/.

## Archivos
```
webapp/
├─ index.html      ← página
├─ style.css       ← estética (colores de marca en :root, fáciles de cambiar)
├─ app.js          ← mapa (Leaflet) + gráficos (Chart.js) + render
├─ data.js         ← DATOS embebidos (los genera build_data.R)
└─ build_data.R    ← MOTOR: calcula las ciudades y el TEXTO automático
```

## Verlo en tu computador
**Doble clic en `index.html`** y se abre en el navegador. Los datos van embebidos en `data.js`,
así que funciona sin servidor (solo necesita internet para cargar el mapa y los gráficos desde su CDN).

## Regenerar los datos (cuando cambien los resultados o agregues ciudades)
En RStudio, con el proyecto abierto:
```r
source("webapp/build_data.R")   # reescribe webapp/data.js
```
- El **motor de texto automático** está en la función `analizar()` de `build_data.R` (bloques
  *diagnóstico / dónde se perdió / qué hacer / a qué público*). Ahí se editan las reglas.
- Para **agregar ciudades**: añade una fila a la tabla `caps` (slug, nombre, departamento, lat, lon)
  y un patrón en `patron`. Se puede escalar a cualquier municipio del país.

## Publicarlo gratis en GitHub Pages (paso a paso)
1. Crea una cuenta en **github.com** (gratis).
2. Crea un repositorio nuevo, p. ej. `caja-herramientas` (público).
3. Sube **el contenido de la carpeta `webapp/`** (index.html, style.css, app.js, data.js) a la raíz
   del repo. (Por la web: *Add file ▸ Upload files*; o con Git: `git init / add / commit / push`.)
4. En el repo ▸ **Settings ▸ Pages** ▸ *Build and deployment* ▸ Source: **Deploy from a branch** ▸
   Branch: `main` / carpeta `/root` ▸ **Save**.
5. En 1–2 minutos queda en `https://TUUSUARIO.github.io/caja-herramientas/`.
6. **Dominio propio (opcional):** en *Settings ▸ Pages ▸ Custom domain* escribe tu dominio y crea en
   tu proveedor de DNS un registro **CNAME** apuntando a `TUUSUARIO.github.io`. HTTPS es automático.

## Personalizar la estética
- Colores: edita las variables en `style.css` (`--brand`, `--accent`, etc.).
- Logo: reemplaza el cuadro “IC” del encabezado por el logo oficial (con autorización de la campaña).
- Fotos: por derechos de imagen, este prototipo no incrusta fotos del candidato; agrégalas solo con
  los assets oficiales autorizados.

## Qué muestra cada ciudad
- KPIs (Cepeda %, swing vs 2022, votos, estado vs. bloque de derecha).
- Textos automáticos: diagnóstico · dónde se perdió · qué hacer · a qué público.
- **Cómo se ganó hace 4 años** (remontada de Petro entre 1ª y 2ª vuelta 2022).
- **Mapa interactivo por puesto de votación** (puntos coloreados por swing; coordenadas reales).
- **Dónde se perdió por comuna/sector**.
- Puestos donde más cayó + fortines.
- **Bogotá**: además, galería de capas (localidad, estrato, UPZ, edad) con su análisis.

## Identidad visual
Colores oficiales de la *Línea gráfica Iván Cepeda 2026*: morado **#544595**, naranja **#F3930D**,
magenta **#874088**; tipografía **Nunito Sans**. Para el logo oficial, deja `webapp/img/logo.png`
(aparece solo; si no, queda el recuadro provisional).

## Datos que necesita `build_data.R`
- `PRECONTEO_REGIS_*.csv` (2026 por mesa) y `datos/crudos/MMV_NACIONAL_PRESIDENTE_2022_1v.csv` y `_2v.csv`.
- `datos/crudos/puestos_georef.json` (coordenadas + comuna por puesto, Datos Abiertos `mv2e-prx5`).
- `datos/crudos/edad_municipal.csv` (perfil etario por ciudad) — lo genera **una vez**
  `webapp/extraer_edad_dane.R` a partir del anexo municipal del DANE (`dane_municipal_edad.xlsx`).
- `webapp/img/*.png` (mapas de Bogotá para la galería).

## Salidas nuevas
- `webapp/geo.js` (`window.APP_GEO`): choropleth por comuna (polígonos Voronoi disueltos por comuna,
  coloreados por el cambio vs. 2022) para las 13 ciudades. Se incluye en `index.html` antes de `app.js`.
- Mapa interactivo por ciudad = choropleth de comunas + puntos de puestos (Leaflet).

## Alcance y límites
- **13 capitales** con dato real por puesto. Villavicencio tiene cobertura parcial de coordenadas
  (los nombres de puesto emparejan poco con la base georreferenciada).
- El texto *“a qué público”* usa el patrón de voto (puestos populares vs. clase media); se puede
  afinar con edad municipal (DANE) cuando se cargue.
- Las **capas tipo Bogotá** (localidad/estrato/UPZ) están listas para Bogotá; para otras ciudades el
  mapa por puesto ya da el detalle territorial.
- **No incluye** sexo ni puntos de flujo (decisión del proyecto). Análisis **por territorio**, no por persona.

Fuentes: Registraduría Nacional (resultados por puesto 2022 y 2026) · Datos Abiertos (georreferenciación de puestos `mv2e-prx5`) · cartografía oficial.
# NOTA MIA 
> [!NOTE]
> Se ha omitido el análisis de 19 ciudades debido a la falta de datos de georreferenciación. Los datos de puestos para estas ciudades no se encuentran disponibles en la base de datos de la Registraduría Nacional
> Se ha modificado el script de datos para que solo se tengan en cuenta los datos de las ciudades con datos de georreferenciación disponibles.

## Para poder agregar las otras ciudades, se necesita:
- Datos ofrecidos por la Registraduría Nacional de Colombia.
- Datos ofrecidos por Datos Abiertos (georreferenciación de puestos).
- Datos ofrecidos por el DANE (perfil etario por ciudad).

Instalar dependencias en R:
```r
install.packages(c("tidyverse", "jsonlite", "sf"))
```

Ejecutar script:
```r
source("build_data.R")
```