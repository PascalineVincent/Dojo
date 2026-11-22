#!/usr/bin/env Rscript
# Valide le contenu (content/*.yml) et génère assets/data.json pour le front (dojo.js).
# Lancé automatiquement avant chaque rendu Quarto (pre-render) ; échoue si le contenu est incohérent.
suppressPackageStartupMessages(library(jsonlite))
source("R/dojo.R")
source("R/veille.R")   # fournit %||%

ct  <- read_content("content")
err <- validate_content(ct, ".")
if (length(err)) {
  message("Contenu invalide :\n", paste0(" - ", err, collapse = "\n"))
  # DOJO_LENIENT=1 : avertir sans bloquer (développement d'une page isolée)
  if (!nzchar(Sys.getenv("DOJO_LENIENT"))) quit(status = 1)
}

veille <- list()
if (file.exists("veille/items.json")) {
  v <- fromJSON("veille/items.json", simplifyVector = FALSE)
  veille <- head(v$items %||% list(), 8)
}


dat <- build_data_json(ct, veille)
dir.create("assets", showWarnings = FALSE)
write_json(dat, "assets/data.json", auto_unbox = TRUE, null = "null")
message(sprintf("[data] %d cartes, %d QCM, %d exercices, défi de la semaine : %s",
                length(ct$cards), length(ct$quiz), length(ct$exercises), dat$defi$id))
