# =====================================================================
# build_data.R  — Motor de datos de la "Caja de Herramientas"
# Calcula el comportamiento electoral y el Swing 2022 -> 2026 para 
# Cartagena y Bolívar utilizando los archivos reales de escrutinio.
# Exporta webapp/data.js y webapp/geo.js para el sitio estático.
# =====================================================================
suppressPackageStartupMessages({library(tidyverse); library(jsonlite); library(sf)})
sf::sf_use_s2(FALSE)
GEO_OUT <- list()   # GeoJSON final para el mapa

# Funciones de normalización de cadenas para emparejamiento elástico
norm <- function(x) toupper(stringi::stri_trans_general(as.character(x),"Latin-ASCII"))
key  <- function(x) str_squish(str_replace_all(norm(x), "[^A-Z0-9 ]", " "))
PREF <- "\\b(IE|INST|INSTITUTO|INSTITUCION|EDUCATIVO|EDUCATIVA|ESCUELA|ESC|COLEGIO|COL|CENTRO|CTRO|HOGAR|JARDIN|IES|GIMNASIO|LICEO|UNIDAD|SEDE|DISTRITAL|DEPARTAMENTAL|MUNICIPAL|RURAL|URBANA|URBANO|MIXTA|SECCION|SEC|PRINCIPAL)\\b"
core <- function(x){ k <- str_remove_all(key(x), PREF)
  vapply(str_split(str_squish(k), " "), function(t){ t <- t[nchar(t)>=3 | grepl("[0-9]",t)]
    paste(sort(unique(t)), collapse=" ") }, character(1)) }

# 1) Georreferenciación base (coordenadas de puestos de Datos Abiertos)
GEO <- jsonlite::fromJSON("datos/crudos/puestos_georef.json") |>
  dplyr::mutate(mk=norm(municipio), dk=norm(departamento), pk=key(puesto), pk2=core(puesto),
                latitud=as.numeric(latitud), longitud=as.numeric(longitud))

# ---- 2) HISTÓRICO 2022: Primera y Segunda Vuelta Nacional ----
# Corregido: Ruta añadida a datos/crudos/
m22 <- readr::read_delim("datos/crudos/MMV_NACIONAL_PRESIDENTE_2022_1v.csv", delim=";",
          locale=locale(encoding="latin1"), col_types=cols(.default="c"), show_col_types=FALSE)
names(m22) <- toupper(names(m22))

# Normalizar códigos geográficos para evitar problemas de ceros a la izquierda
m22 <- m22 |>
  mutate(cod_puesto = paste0(str_pad(DEP,2,pad="0"), str_pad(MUN,3,pad="0"), str_pad(ZONA,2,pad="0"), str_pad(PUESTO,2,pad="0")),
         votos = as.numeric(VOTOS), cn = norm(CANNOMBRE),
         tipo = case_when(str_detect(cn,"NULO|NO MARCAD") ~ "nv",
                        str_detect(cn,"PETRO") ~ "izq",
                        str_detect(cn,"GUTIERREZ|HERNANDEZ") ~ "der", TRUE ~ "ov"))

xwalk <- m22 |> distinct(DEP, MUN, DEPNOMBRE, MUNNOMBRE) |>
  mutate(dep=str_pad(DEP,2,pad="0"), mun=str_pad(MUN,3,pad="0"), depn=norm(DEPNOMBRE), munn=norm(MUNNOMBRE))
pnom <- m22 |> distinct(cod_puesto, PUESNOMBRE) |> rename(puesto_nom=PUESNOMBRE)

v22 <- m22 |> group_by(dep=str_pad(DEP,2,pad="0"), mun=str_pad(MUN,3,pad="0"), cod_puesto) |>
  summarise(izq22=sum(votos[tipo=="izq"]), val22=sum(votos[tipo!="nv"]), .groups="drop")

# 2022 Segunda Vuelta
# Corregido: Ruta añadida a datos/crudos/
m2v <- readr::read_delim("datos/crudos/MMV_NACIONAL_PRESIDENTE_2022_2v.csv", delim=";",
          locale=locale(encoding="latin1"), col_types=cols(.default="c"), show_col_types=FALSE)
names(m2v) <- toupper(names(m2v))
v2v <- m2v |> mutate(votos=as.numeric(VOTOS), cn=norm(CANNOMBRE),
          tipo=case_when(str_detect(cn,"NULO|NO MARCAD")~"nv", str_detect(cn,"PETRO")~"izq", TRUE~"ov")) |>
  group_by(dep=str_pad(DEP,2,pad="0"), mun=str_pad(MUN,3,pad="0")) |>
  summarise(izq2v=sum(votos[tipo=="izq"]), val2v=sum(votos[tipo!="nv"]), .groups="drop")


# ---- 3) PROCESAMIENTO DE TUS ARCHIVOS NUEVOS (2026) ----

# A. Cargar Escrutinio Mesa a Mesa de Cartagena
# Corregido: Ruta añadida a datos/crudos/
p26 <- readr::read_csv("datos/crudos/MMV_Cartagena Escrutinio.csv", col_types=cols(.default="c"), show_col_types=FALSE)
names(p26) <- toupper(names(p26))

p26_procesado <- p26 |>
  mutate(votos = as.numeric(VOTOS),
         cod_puesto = paste0(str_pad(DEP,2,pad="0"), str_pad(MUN,3,pad="0"), str_pad(ZONA,2,pad="0"), str_pad(PUESTO,2,pad="0")),
         cn = norm(CANNOMBRE),
         comuna_lbl = str_to_title(str_replace(norm(COMUNOMBRE), "^(LOC\\.? *[0-9]* *|LOCALIDAD *[0-9]* *)", ""))) |>
  group_by(dep=str_pad(DEP,2,pad="0"), mun=str_pad(MUN,3,pad="0"), cod_puesto, comuna_lbl) |>
  summarise(
    cep26 = sum(votos[str_detect(cn, "CEPEDA")], na.rm=TRUE),
    der26 = sum(votos[str_detect(cn, "ESPRIELLA|ABELARDO")], na.rm=TRUE),
    val26 = sum(votos[!str_detect(cn, "NULO|NO MARCAD")], na.rm=TRUE),
    .groups = "drop"
  )

# B. Cargar Consolidado Departamental de Bolívar
# Corregido: Ruta añadida a datos/crudos/
bolivar_muns <- readr::read_csv("datos/crudos/bolivar_ganadores.csv", show_col_types=FALSE)
names(bolivar_muns) <- toupper(names(bolivar_muns))
bolivar_muns <- bolivar_muns |> mutate(MUNICIPIO_NORM = norm(MUNICIPIO))


# ---- 4) CONFIGURACIÓN GEOGRÁFICA DE CARTAGENA ----
caps <- tribble(
  ~slug,~ciudad,~depn,~lat,~lon,
  "cartagena","Cartagena","BOLIVAR",10.39,-75.51)

patron <- c(cartagena="CARTAGENA")

resolver <- function(slug){
  dn <- norm(caps$depn[caps$slug==slug]); pt <- patron[[slug]]
  cand <- xwalk |> filter(str_detect(depn, fixed(dn)), str_detect(munn, pt))
  if(nrow(cand)==0) return(NULL)
  cand |> left_join(v22 |> group_by(dep,mun) |> summarise(v=sum(val22),.groups="drop"), by=c("dep","mun")) |>
    arrange(desc(v)) |> slice(1)
}


# ---- 5) MOTOR DE ANÁLISIS ELECTORAL Y TEXTOS AUTOMÁTICOS ----
fmt <- function(x) format(round(x), big.mark=".", decimal.mark=",")
pct <- function(x) paste0(format(round(100*x,1), decimal.mark=","),"%")
pts <- function(x) paste0(ifelse(x>=0,"+",""), format(round(x,1), decimal.mark=","), " pts")

analizar <- function(slug){
  r <- resolver(slug); if(is.null(r)) return(NULL)
  d <- r$dep; mu <- r$mun
  
  a26 <- p26_procesado |> filter(dep==d, mun==mu)
  a22 <- v22 |> filter(dep==d, mun==mu)
  
  pu <- a26 |> inner_join(a22, by=c("dep","mun","cod_puesto")) |>
    left_join(pnom, by="cod_puesto") |>
    mutate(izq22p=izq22/val22, izq26p=cep26/val26, swing=izq26p-izq22p)
    
  if(nrow(pu)<3) return(NULL)
  
  gm <- GEO |> filter(str_detect(mk, patron[[slug]]), str_detect(dk, norm(caps$depn[caps$slug==slug])))
  xy1 <- gm |> group_by(pk)  |> slice(1) |> ungroup() |> select(pk, latitud, longitud)
  xy2 <- gm |> filter(pk2!="") |> group_by(pk2) |> slice(1) |> ungroup() |> select(pk2, la2=latitud, lo2=longitud)
  
  pu <- pu |> mutate(pk=key(puesto_nom), pk2=core(puesto_nom)) |>
    left_join(xy1, by="pk") |> left_join(xy2, by="pk2") |>
    mutate(latitud=coalesce(latitud, la2), longitud=coalesce(longitud, lo2)) |>
    select(-la2, -lo2, -pk2)
    
  cep <- sum(pu$cep26)/sum(pu$val26)
  der <- sum(pu$der26)/sum(pu$val26)
  pet <- sum(pu$izq22)/sum(pu$val22)
  sw <- cep-pet
  ciu <- caps$ciudad[caps$slug==slug]

  a2v <- v2v |> filter(dep==d, mun==mu)
  pet2 <- if(nrow(a2v)>0 && sum(a2v$val2v)>0) sum(a2v$izq2v)/sum(a2v$val2v) else NA
  crec22 <- if(!is.na(pet2)) pet2-pet else NA
  ganados22 <- if(!is.na(pet2)) round(sum(a2v$izq2v) - sum(pu$izq22)) else NA

  unidad  <- "localidades"; unidadS <- "localidad"
  
  comT <- pu |> filter(!is.na(comuna_lbl), comuna_lbl!="") |>
    group_by(comuna=comuna_lbl) |>
    summarise(c26=sum(cep26), i22=sum(izq22), v26=sum(val26), v22=sum(val22), .groups="drop") |>
    mutate(apoyo=c26/v26, swing=apoyo - i22/v22, votos=round(c26), total=round(v26)) |>
    filter(v26 >= 100)
    
  mklist <- function(df) df |> transmute(comuna, apoyo=round(100*apoyo,1), swing=round(100*swing,1), votos, total) |>
    {\(x) pmap(x, function(comuna,apoyo,swing,votos,total) list(comuna=comuna,apoyo=apoyo,swing=swing,votos=votos,total=total))}()
    
  recuperarT  <- comT |> filter(swing < 0) |> arrange(swing) |> slice_head(n=3)
  fortalecerT <- comT |> filter(apoyo>=.50) |> arrange(desc(votos)) |> slice_head(n=4)
  topfall <- head(comT |> arrange(swing) |> pull(comuna), 2)
  nom_rec <- head(recuperarT$comuna,2); nom_for <- head(fortalecerT$comuna,2)
  jn <- function(x) if(length(x)) paste(x, collapse=", ") else "—"

  margen <- cep - der
  estado <- if(margen >= .05) "ganada" else if(margen >= -.05) "disputa" else "adversa"

  diag <- sprintf("En %s, Cepeda obtuvo %s frente a %s de De la Espriella. Respecto a Petro 2022 (%s), el bloque alternativo %s %s puntos. El analisis se despliega por %s territoriales.",
                  ciu, pct(cep), pct(der), pct(pet), ifelse(sw<0,"cayo","subio"), format(round(100*abs(sw),1), decimal.mark=","), unidad)
  donde <- sprintf("La variacion del comportamiento electoral se concentro en las %s: %s.", unidad, jn(topfall))
  
  gano22 <- if(!is.na(pet2))
    sprintf("Hace 4 anos Petro paso de %s a %s en la 2a vuelta (+%s votos en la ciudad). Esa es la ruta de movilizacion de referencia.", pct(pet), pct(pet2), fmt(ganados22)) else "Sin dato historico de 2a vuelta."
  
  quehacer <- sprintf("Estrategia para %s (%s): Proteger zonas base en %s y mitigar caidas en %s.", ciu, estado, jn(nom_for), jn(nom_rec))

  # ---- CONSTRUCCIÓN DEL MAPA DE COMUNAS/LOCALIDADES CON UNIDAD POLIGONAL ----
  thumb <- NA
  ptsf <- pu |> filter(!is.na(latitud), !is.na(longitud), !is.na(comuna_lbl), comuna_lbl!="") |> distinct(longitud, latitud, .keep_all=TRUE)
  if(nrow(ptsf) >= 5 && n_distinct(ptsf$comuna_lbl) >= 2){
    sfp <- st_as_sf(ptsf, coords=c("longitud","latitud"), crs=4326)
    vor <- st_collection_extract(st_voronoi(st_union(sfp)), "POLYGON") |> st_sf(geometry=_) |> st_set_crs(4326)
    vor <- st_join(vor, sfp["comuna_lbl"], join=st_intersects, left=FALSE)
    hull <- st_buffer(st_convex_hull(st_union(sfp)), 0.004)
    vor <- suppressWarnings(st_intersection(vor, hull))
    com <- vor |> group_by(comuna_lbl) |> summarise(.groups="drop") |> st_simplify(dTolerance=0.0006, preserveTopology=TRUE)
    
    stats <- pu |> filter(!is.na(comuna_lbl), comuna_lbl!="") |> group_by(comuna_lbl) |>
      summarise(swing=round(100*(sum(cep26)/sum(val26)-sum(izq22)/sum(val22)),1),
                apoyo=round(100*sum(cep26)/sum(val26),1), votos=round(sum(cep26)), total=round(sum(val26)), .groups="drop")
    
    com <- com |> left_join(stats, by="comuna_lbl") |> rename(comuna=comuna_lbl)
    tmpf <- tempfile(fileext=".geojson")
    suppressWarnings(st_write(com, tmpf, quiet=TRUE, delete_dsn=TRUE))
    GEO_OUT[[slug]] <<- paste(readLines(tmpf, warn=FALSE), collapse="")
    unlink(tmpf)
    
    dir.create("webapp/img/maps", showWarnings=FALSE, recursive=TRUE)
    th <- ggplot2::ggplot(com) +
      ggplot2::geom_sf(ggplot2::aes(fill=swing), color="white", linewidth=.12) +
      ggplot2::scale_fill_gradient2(low="#7f0000", mid="#ece9f3", high="#544595", midpoint=0, guide="none") +
      ggplot2::theme_void()
    suppressWarnings(ggplot2::ggsave(sprintf("webapp/img/maps/%s.png", slug), th, width=3.4, height=3, dpi=80, bg="white"))
    thumb <- sprintf("img/maps/%s.png", slug)
  }

  puntos <- pu |> filter(!is.na(latitud), !is.na(longitud)) |>
    transmute(lat=round(latitud,5), lon=round(longitud,5), sw=round(100*swing,1),
              v=round(cep26), ap=round(100*izq26p), n=str_to_title(tolower(puesto_nom))) |>
    {\(x) pmap(x, function(lat,lon,sw,v,ap,n) list(lat=lat,lon=lon,sw=sw,v=v,ap=ap,n=n))}()
    
  list(slug=slug, ciudad=ciu, depto=r$DEPNOMBRE |> str_to_title(), unidad=unidadS, thumb=thumb,
       puntos=puntos, n_geo=length(puntos),
       recuperar=mklist(recuperarT), fortalecer=mklist(fortalecerT),
       lat=caps$lat[caps$slug==slug], lon=caps$lon[caps$slug==slug],
       estado=estado, cepeda=round(100*cep,1), derecha=round(100*der,1),
       petro22=round(100*pet,1), swing=round(100*sw,1),
       petro2v=if(!is.na(pet2)) round(100*pet2,1) else NA,
       votos_cepeda=round(sum(pu$cep26)), votos_total=round(sum(pu$val26)), n_puestos=nrow(pu),
       texto=list(diagnostico=diag, donde=donde, gano22=gano22, quehacer=quehacer))
}

res <- map(caps$slug, analizar) |> compact()
names(res) <- map_chr(res, "slug")

# Mensaje de verificación en consola con los datos leídos de los municipios ganadores de Bolívar
cat("\n--- Reporte del Proceso ---\n")
cat("Municipios de Bolívar indexados en archivo consolidado:", nrow(bolivar_muns), "\n")
for(c in res) cat(sprintf("Ciudad: %s | Votos Cepeda: %s | Swing Global: %s pts\n", c$ciudad, fmt(c$votos_cepeda), c$swing))

# ---- 6) EXPORTACIÓN DE ENTREGABLES ESTRATÉGICOS ----
idx <- map(res, \(c) c[c("slug","ciudad","depto","lat","lon","estado","cepeda","derecha","swing","votos_cepeda","votos_total","thumb")])
payload <- list(generado=as.character(Sys.Date()), ciudades=unname(idx), detalle=res)
writeLines(paste0("window.APP_DATA=", toJSON(payload, auto_unbox=TRUE, pretty=FALSE), ";"), "webapp/data.js")
writeLines(paste0("window.APP_GEO={", paste(sprintf('"%s":%s', names(GEO_OUT), GEO_OUT), collapse=","), "};"), "webapp/geo.js")
cat("\nArchivos webapp/data.js y webapp/geo.js actualizados con éxito.\n")