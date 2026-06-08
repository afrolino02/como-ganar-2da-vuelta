library(readxl)
library(readr)
library(stringr)

convert_file <- function(filepath, output_name = NULL) {
  cat("Converting", filepath, "...\n")
  sheets <- excel_sheets(filepath)
  for (sheet in sheets) {
    df <- read_excel(filepath, sheet = sheet)
    
    # Generate clean output name
    if (is.null(output_name)) {
      base_name <- str_remove(basename(filepath), "\\.xlsx$|\\.xls$")
      if (length(sheets) == 1) {
        out_file <- file.path(dirname(filepath), paste0(base_name, ".csv"))
      } else {
        out_file <- file.path(dirname(filepath), paste0(base_name, "_", clean_name(sheet), ".csv"))
      }
    } else {
      out_file <- output_name
    }
    
    write_csv(df, out_file)
    cat("Saved sheet '", sheet, "' to '", out_file, "'\n", sep = "")
  }
}

clean_name <- function(x) {
  x <- str_replace_all(x, "[^a-zA-Z0-9_]", "_")
  x <- str_replace_all(x, "_+", "_")
  x <- str_remove_all(x, "^_|_+")
  x
}

convert_file("datos/crudos/Bolivar.xlsx")
convert_file("datos/crudos/bolivar_ganadores.xlsx")
convert_file("datos/crudos/DATOS ELECCIONESv2_Miguel Mapa.xlsx")

convert_file("datos/crudos/MMV_Cartagena Escrutinio.xlsx")
cat("Done conversion!\n")
