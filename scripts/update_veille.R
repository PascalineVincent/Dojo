#!/usr/bin/env Rscript
# Met à jour veille/items.json (OpenAlex + arXiv). À lancer depuis la racine du projet :
#   Rscript scripts/update_veille.R
# Ensuite : quarto render (pour afficher la veille sur le site).
# Le script dit clairement ce qui s'est passé ; il n'écrase l'existant que s'il a récupéré quelque chose.

# ---- 0. Vérifications préalables --------------------------------------------------
if (!file.exists("content/veille_config.yml")) {
  stop("Lance ce script depuis la racine du projet (le dossier qui contient _quarto.yml). Dossier actuel : ", getwd(), call. = FALSE)
}
need <- c("yaml", "jsonlite", "httr2", "xml2")
miss <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) {
  stop("Paquets R manquants : ", paste(miss, collapse = ", "), ".\n  Installe-les avec : install.packages(c(",
       paste(sprintf('"%s"', miss), collapse = ", "), "))", call. = FALSE)
}
suppressPackageStartupMessages({ library(yaml); library(jsonlite) })
source("R/dojo.R"); source("R/veille.R")

cfg   <- read_yaml_utf8("content/veille_config.yml")
since <- Sys.Date() - cfg$window_days
path  <- "veille/items.json"
old   <- if (file.exists(path)) fromJSON(path, simplifyVector = FALSE)$items else list()

# ---- 1. Collecte -----------------------------------------------------------------
errors <- character()
safe <- function(label, expr) tryCatch(expr, error = function(e) {
  errors <<- c(errors, sprintf("%s : %s", label, conditionMessage(e)))
  list()
})

n_oa <- 0L; n_oa_fail <- 0L; streak <- 0L; collected <- list()
message("[veille] OpenAlex ...")
for (tp in cfg$topics) for (q in tp$queries) {
  if (streak >= 2 && n_oa == 0L) break          # connexion manifestement impossible : inutile d'attendre toutes les requêtes
  before <- length(errors)
  got <- safe(paste("OpenAlex", q), fetch_openalex(q, format(since), cfg$openalex$per_query))
  failed <- length(errors) > before
  if (failed) { n_oa_fail <- n_oa_fail + 1L; streak <- streak + 1L } else streak <- 0L
  n_oa <- n_oa + length(got); collected <- c(collected, got)
  Sys.sleep(0.2)
}
if (streak >= 2 && n_oa == 0L) message("[veille] OpenAlex injoignable : les requêtes suivantes sont ignorées.")
message(sprintf("[veille] OpenAlex : %d notices, %d requête(s) en échec", n_oa, n_oa_fail))

message("[veille] arXiv ...")
before <- length(errors)
got_ax <- safe("arXiv", fetch_arxiv(cfg$arxiv$categories, cfg$arxiv$max_results))
message(sprintf("[veille] arXiv : %d notices%s", length(got_ax), if (length(errors) > before) " (ÉCHEC)" else ""))
collected <- c(collected, got_ax)

# ---- 2. Si rien n'a pu être récupéré : on s'arrête sans rien écraser ---------------
if (length(collected) == 0) {
  message("\n[veille] AUCUNE notice récupérée. veille/items.json n'a PAS été modifié.")
  if (length(errors)) {
    message("Première erreur rencontrée :\n  ", errors[1])
    if (any(grepl("SSL|certificate|schannel|CRYPT", errors, ignore.case = TRUE)))
      message("Piste : problème de certificat (réseau d'entreprise/université). Essaie depuis un autre réseau (partage de connexion du téléphone).")
    else if (any(grepl("proxy|407|403|resolve|Could not|timeout|timed out|connect", errors, ignore.case = TRUE)))
      message("Piste : connexion bloquée (pare-feu, proxy, VPN) ou pas d'Internet. Essaie depuis un autre réseau.")
  } else {
    message("Aucune erreur, mais aucune notice : vérifie content/veille_config.yml (window_days, requêtes).")
  }
  quit(status = 1)
}

# ---- 3. Score, fusion, écriture ---------------------------------------------------
scored <- score_items(collected, cfg$topics)
items  <- merge_items(old, scored, cfg$min_score, since, cfg$max_items)
dir.create("veille", showWarnings = FALSE)
write_json(list(updated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), items = items),
           path, auto_unbox = TRUE, pretty = TRUE)
message(sprintf("[veille] %d notices collectées, %d retenues (score >= %s), écrites dans %s",
                length(collected), length(items), cfg$min_score, path))
if (length(items) == 0)
  message("Aucune notice ne passe le filtre : baisse min_score (ou élargis window_days) dans content/veille_config.yml.")
if (length(errors)) message(sprintf("[veille] %d requête(s) en échec (non bloquant). Exemple : %s", length(errors), errors[1]))
message("[veille] Étape suivante : quarto render")
