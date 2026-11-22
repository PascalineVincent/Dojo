#!/usr/bin/env Rscript
# Banc d'essai des exercices interactifs (sans navigateur).
#  - structure : chaque exercice du catalogue a gabarit, indice, solution, correction, bouton « réussi », ancre ;
#  - paramètres : les cellules OJS sont évaluées avec Node sur plusieurs dates et graines ;
#  - correction : la solution doit être validée pour tous les tirages ; une mauvaise réponse doit être refusée ;
#  - les blocs « terrain de jeu » (sans exercice) s'exécutent sans erreur.
# Lancer depuis la racine du dépôt : Rscript scripts/test_exercices.R
suppressPackageStartupMessages(library(jsonlite))
source("R/dojo.R")
invisible(pdf(NULL))

pages <- c(list.files("parcours", "\\.qmd$", full.names = TRUE), list.files("recherche", "\\.qmd$", full.names = TRUE))
DAYS <- c("2026-01-01", "2026-06-15", "2026-11-22")
SALTS <- 0:9
fails <- character(); n_checks <- 0L
fail <- function(msg) fails <<- c(fails, msg)

# ---- extraction des blocs ------------------------------------------------------
parse_blocks <- function(file) {
  L <- readLines(file, encoding = "UTF-8", warn = FALSE)
  out <- list(); i <- 1
  while (i <= length(L)) {
    m <- regmatches(L[i], regexec("^```\\{(webr|ojs)\\}\\s*$", L[i]))[[1]]
    if (length(m)) {
      j <- i + 1; while (j <= length(L) && !grepl("^```\\s*$", L[j])) j <- j + 1
      body <- L[(i + 1):(j - 1)]
      is_opt <- grepl("^(#\\||//\\|)", body)
      opts <- list(); cur <- NULL
      for (ln in body[is_opt]) {
        ln <- sub("^(#\\||//\\|)\\s?", "", ln)
        if (grepl("^\\s+- ", ln)) opts[[cur]] <- c(opts[[cur]], sub("^\\s+- ", "", ln))
        else { kv <- regmatches(ln, regexec("^([A-Za-z-]+):\\s*(.*)$", ln))[[1]]; cur <- kv[2]; opts[[cur]] <- if (nzchar(kv[3])) kv[3] else character() }
      }
      out[[length(out) + 1]] <- list(file = file, lang = m[2], opts = opts, code = paste(body[!is_opt], collapse = "\n"), line = i)
      i <- j
    }
    i <- i + 1
  }
  out
}
truthy <- function(b, k) identical(tolower(b$opts[[k]] %||% ""), "true")
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

blocks <- do.call(c, lapply(pages, parse_blocks))
webr <- Filter(function(b) b$lang == "webr", blocks)
ojs  <- Filter(function(b) b$lang == "ojs", blocks)

# ---- évaluation des paramètres OJS par Node ----------------------------------
ojs_cell <- function(file, name) {
  for (b in Filter(function(b) b$file == file, ojs)) {
    if (grepl(sprintf("^\\s*%s\\s*=", name), b$code)) return(b$code)
  }
  NULL
}
ojs_params <- function(file, names) {
  rng_cell <- Filter(function(b) grepl("^\\s*rng\\s*=", b$code), parse_blocks("_ojs.qmd"))[[1]]$code
  rng_cell <- sub("(?s)\\n\\s*viewof salt.*$", "", rng_cell, perl = TRUE)   # garde la seule cellule rng
  rng_body <- sub("^\\s*rng\\s*=\\s*", "", rng_cell)
  js <- c(sprintf("const rng = (() => %s)();", rng_body),
          'const out = [];',
          sprintf('for (const day of %s) for (const salt of %s) {', toJSON(DAYS, auto_unbox = FALSE), toJSON(SALTS)),
          '  const rng2 = (id, s) => rng(id, s, day); const draw = {};')
  for (nm in names) {
    code <- ojs_cell(file, nm)
    if (is.null(code)) return(NULL)
    body <- sub(sprintf("^\\s*%s\\s*=\\s*", nm), "", code)
    body <- gsub("rng\\(", "rng2(", body)
    js <- c(js, sprintf("  draw.%s = (() => %s)();", nm, body))
  }
  js <- c(js, '  out.push(draw); }', 'console.log(JSON.stringify(out));')
  f <- tempfile(fileext = ".mjs"); writeLines(js, f)
  res <- system2("node", f, stdout = TRUE, stderr = TRUE)
  tryCatch(fromJSON(paste(res, collapse = ""), simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE),
           error = function(e) stop("Node/OJS : ", paste(res, collapse = "\n")))
}

# ---- exercices -----------------------------------------------------------------
exo_labels <- unique(vapply(Filter(function(b) !is.null(b$opts$exercise), webr), function(b) b$opts$exercise, ""))
catalog <- read_content("content")$exercises
cat_ids <- vapply(catalog, `[[`, "", "id")
for (id in setdiff(cat_ids, exo_labels)) fail(sprintf("[%s] présent dans le catalogue mais sans bloc webr", id))
for (id in setdiff(exo_labels, cat_ids)) fail(sprintf("[%s] exercice absent du catalogue content/exercices.yml", id))

run_check <- function(chk, sol_val, env_prep, env_res) {
  e <- new.env(parent = env_res)
  assign(".result", sol_val, e); assign(".last_value", sol_val, e)
  assign(".envir_prep", env_prep, e); assign(".envir_result", env_res, e); assign(".label", "x", e)
  eval(parse(text = chk), e)
}

# ---- piège Pandoc : « ${x} » précédé d'un caractère non blanc dans un paragraphe qui contient d'autres « $ »
#      est pris pour une formule mathématique et avale les chiffres de l'énoncé.
for (file in pages) {
  L <- readLines(file, encoding = "UTF-8", warn = FALSE)
  in_code <- FALSE; para <- character(); start <- 1
  flush <- function() {
    txt <- paste(para, collapse = " ")
    n_dollar <- lengths(regmatches(txt, gregexpr("$", txt, fixed = TRUE)))
    if (n_dollar >= 2 && grepl("[^ \t]\\$\\{", txt)) fail(sprintf("%s (l.%d) : « ${...} » collé à un autre caractère dans un paragraphe à plusieurs $ ; mets une espace avant ${ ou retire le gras", file, start))
  }
  for (i in seq_along(L)) {
    if (grepl("^```", L[i])) { in_code <- !in_code; next }
    if (in_code) next
    if (!nzchar(trimws(L[i]))) { if (length(para)) flush(); para <- character() }
    else { if (!length(para)) start <- i; para <- c(para, L[i]) }
  }
  if (length(para)) flush()
}

for (id in exo_labels) {
  bl <- Filter(function(b) identical(b$opts$exercise, id), webr)
  file <- bl[[1]]$file
  starter  <- Filter(function(b) !truthy(b, "setup") && !truthy(b, "solution") && !truthy(b, "check"), bl)
  solution <- Filter(function(b) truthy(b, "solution"), bl)
  check    <- Filter(function(b) truthy(b, "check"), bl)
  setup    <- Filter(function(b) truthy(b, "setup"), bl)
  src <- paste(readLines(file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  if (length(starter) != 1) { fail(sprintf("[%s] %d gabarit(s) au lieu de 1", id, length(starter))); next }
  if (length(solution) != 1) { fail(sprintf("[%s] %d solution(s) au lieu de 1", id, length(solution))); next }
  if (length(check) != 1)    { fail(sprintf("[%s] %d correction(s) au lieu de 1", id, length(check))); next }
  if (!grepl("______", starter[[1]]$code, fixed = TRUE)) fail(sprintf("[%s] le gabarit ne contient aucun trou (______)", id))
  n_hint <- lengths(regmatches(src, gregexpr(sprintf('{.hint exercise="%s"}', id), src, fixed = TRUE)))
  if (n_hint < 2) fail(sprintf("[%s] %d indice(s) : il en faut au moins 2 (orientation, puis formule)", id, n_hint))
  # corrigé détaillé : raisonnement + pièges fréquents, dans le bloc .solution
  sol_pat <- sprintf('::: {.solution exercise="%s"}', id)
  at <- regexpr(sol_pat, src, fixed = TRUE)
  if (at < 0) {
    fail(sprintf("[%s] bloc .solution introuvable", id))
  } else {
    rest <- substr(src, at, nchar(src))
    body <- sub("\n:::\\s*\n.*$", "", rest)
    for (need in c("**Raisonnement.**", "**Pièges fréquents.**"))
      if (!grepl(need, body, fixed = TRUE)) fail(sprintf("[%s] corrigé incomplet : « %s » manquant", id, need))
    if (nchar(gsub("```.*?```", "", body)) < 450) fail(sprintf("[%s] corrigé trop court (< 450 caractères de texte)", id))
  }
  if (!grepl(sprintf('{.dojo-done data-id="%s"}', id), src, fixed = TRUE)) fail(sprintf("[%s] bouton « réussi » manquant", id))
  if (!grepl(sprintf("{#%s}", id), src, fixed = TRUE)) fail(sprintf("[%s] ancre de section manquante", id))

  inputs <- starter[[1]]$opts$input %||% character()
  draws <- if (length(inputs)) ojs_params(file, inputs) else list(list())
  if (is.null(draws)) { fail(sprintf("[%s] cellule OJS introuvable pour l'entrée %s", id, paste(inputs, collapse = ","))); next }

  for (k in seq_along(draws)) {
    env_prep <- new.env(parent = globalenv())
    for (nm in names(draws[[k]])) assign(nm, draws[[k]][[nm]], env_prep)
    env_res <- new.env(parent = env_prep)
    res <- tryCatch({
      for (b in setup) eval(parse(text = b$code), env_prep)
      withVisible(eval(parse(text = solution[[1]]$code), env_res))
    }, error = function(e) e)
    if (inherits(res, "error")) { fail(sprintf("[%s] tirage %d : la solution plante : %s", id, k, conditionMessage(res))); break }
    val <- res$value
    out <- tryCatch(run_check(check[[1]]$code, val, env_prep, env_res), error = function(e) e)
    n_checks <- n_checks + 1L
    if (inherits(out, "error")) { fail(sprintf("[%s] tirage %d : la correction plante : %s", id, k, conditionMessage(out))); break }
    if (!isTRUE(out$correct)) { fail(sprintf("[%s] tirage %d : la solution est refusée (%s)", id, k, out$message)); break }
    if (is.null(out$message) || !nzchar(out$message)) fail(sprintf("[%s] message de correction vide", id))

    # mauvaises réponses : doivent être refusées sans planter
    wrong <- list(NULL, NA, "texte")
    if (is.numeric(val) && length(val) > 0 && !anyNA(val)) { wrong <- c(wrong, list(val * 1.07 + 0.3, rev(val), val[-1])) }
    env_empty <- new.env(parent = env_prep)                       # l'élève n'a rien défini
    wrong <- Filter(function(w) !isTRUE(all.equal(w, val, check.attributes = FALSE)), wrong)   # ex. palindromes
    for (w in wrong) {
      o2 <- tryCatch(run_check(check[[1]]$code, w, env_prep, env_empty), error = function(e) e)
      if (inherits(o2, "error")) { fail(sprintf("[%s] la correction plante sur une réponse fausse (%s)", id, conditionMessage(o2))); break }
      if (isTRUE(o2$correct)) { fail(sprintf("[%s] une mauvaise réponse est acceptée : %s", id, paste(format(w), collapse = " "))); break }
      n_checks <- n_checks + 1L
    }
    if (length(fails) > 0 && grepl(sprintf("^\\[%s\\]", id), tail(fails, 1))) break
  }
}

# ---- terrains de jeu (blocs sans exercice) ---------------------------------------
for (b in Filter(function(b) is.null(b$opts$exercise), webr)) {
  r <- tryCatch({ eval(parse(text = b$code), new.env(parent = globalenv())); NULL }, error = function(e) conditionMessage(e))
  if (!is.null(r)) fail(sprintf("bloc libre %s:%d : %s", basename(b$file), b$line, r))
  n_checks <- n_checks + 1L
}

cat(sprintf("%d exercices, %d vérifications exécutées.\n", length(exo_labels), n_checks))
if (length(fails)) { cat("ÉCHECS :\n"); cat(paste0(" - ", fails, "\n"), sep = ""); quit(status = 1) }
cat("Tous les exercices sont valides.\n")
