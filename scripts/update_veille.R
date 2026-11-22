#!/usr/bin/env Rscript
# Met à jour veille/items.json (OpenAlex + arXiv). À lancer depuis la racine du dépôt.
# En cas d'échec réseau sur une source, on conserve l'existant et on continue.
suppressPackageStartupMessages({ library(yaml); library(jsonlite) })
source("R/dojo.R"); source("R/veille.R")

cfg   <- read_yaml_utf8("content/veille_config.yml")
since <- Sys.Date() - cfg$window_days
path  <- "veille/items.json"
old   <- if (file.exists(path)) fromJSON(path, simplifyVector = FALSE)$items else list()

collected <- list()
safe <- function(label, expr) tryCatch(expr, error = function(e) {
  message(sprintf("[veille] %s : échec (%s)", label, conditionMessage(e))); list()
})

for (tp in cfg$topics) for (q in tp$queries) {
  collected <- c(collected, safe(paste("OpenAlex", q),
    fetch_openalex(q, format(since), cfg$openalex$per_query)))
  Sys.sleep(0.2)
}
collected <- c(collected, safe("arXiv", fetch_arxiv(cfg$arxiv$categories, cfg$arxiv$max_results)))

message(sprintf("[veille] %d notices collectées", length(collected)))
scored <- score_items(collected, cfg$topics)
items  <- merge_items(old, scored, cfg$min_score, since, cfg$max_items)

dir.create("veille", showWarnings = FALSE)
write_json(list(updated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), items = items),
           path, auto_unbox = TRUE, pretty = TRUE)
message(sprintf("[veille] %d items écrits dans %s", length(items), path))
