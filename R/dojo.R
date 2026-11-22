# ==============================================================================
# Outils de build du Dojo : validation du contenu, défi de la semaine, export JSON.
# ==============================================================================

COURSES <- c("micro", "stats", "econometrie", "histoire", "contemporaine", "recherche", "r")

#' Lecture YAML en UTF-8, indépendante de la locale de la session R
read_yaml_utf8 <- function(path) {
  txt <- readLines(path, encoding = "UTF-8", warn = FALSE)
  yaml::yaml.load(paste(txt, collapse = "\n"))
}

read_content <- function(dir = "content") {
  rd <- function(f) read_yaml_utf8(file.path(dir, f))
  list(cards = rd("flashcards.yml"), quiz = rd("quiz.yml"), defis = rd("defis.yml"),
       exercises = rd("exercices.yml"), biblio = rd("biblio_socle.yml"))
}

#' Vérifie la cohérence du contenu ; renvoie un vecteur de messages d'erreur (vide si OK)
validate_content <- function(ct, qmd_dir = ".") {
  err <- character()
  need <- function(x, fields, label) {
    for (f in fields) if (is.null(x[[f]]) || !nzchar(as.character(x[[f]])[1]))
      err <<- c(err, sprintf("%s : champ '%s' manquant", label, f))
  }
  uniq <- function(ids, what) {
    d <- ids[duplicated(ids)]
    if (length(d)) err <<- c(err, sprintf("%s : identifiants en double : %s", what, paste(d, collapse = ", ")))
  }
  for (x in ct$cards) {
    need(x, c("id", "course", "level", "q", "a"), paste("carte", x$id))
    if (!x$course %in% COURSES) err <- c(err, sprintf("carte %s : cours inconnu '%s'", x$id, x$course))
  }
  uniq(vapply(ct$cards, `[[`, "", "id"), "flashcards")
  for (x in ct$quiz) {
    need(x, c("id", "course", "q", "choices", "answer", "why"), paste("qcm", x$id))
    if (!x$course %in% COURSES) err <- c(err, sprintf("qcm %s : cours inconnu", x$id))
    if (length(x$choices) < 2 || x$answer < 0 || x$answer >= length(x$choices))
      err <- c(err, sprintf("qcm %s : réponse hors bornes", x$id))
  }
  uniq(vapply(ct$quiz, `[[`, "", "id"), "quiz")
  for (x in ct$defis) need(x, c("id", "titre", "niveau", "minutes", "xp", "enonce", "page"), paste("défi", x$id))
  uniq(vapply(ct$defis, `[[`, "", "id"), "défis")
  # chaque défi doit avoir son corrigé (ancre dans recherche/defis.qmd)
  dsrc <- file.path(qmd_dir, "recherche", "defis.qmd")
  dlines <- if (file.exists(dsrc)) readLines(dsrc, warn = FALSE) else character()
  for (x in ct$defis) if (!any(grepl(sprintf("{#%s}", x$id), dlines, fixed = TRUE)))
    err <- c(err, sprintf("défi %s : corrigé absent (ancre {#%s} dans recherche/defis.qmd)", x$id, x$id))
  for (x in ct$exercises) {
    need(x, c("id", "course", "level", "minutes", "xp", "title", "page"), paste("exercice", x$id))
    # l'ancre doit exister dans la page source
    src <- file.path(qmd_dir, sub("\\.html$", ".qmd", x$page))
    if (!file.exists(src)) {
      err <- c(err, sprintf("exercice %s : page source introuvable (%s)", x$id, src))
    } else if (!any(grepl(sprintf("{#%s}", x$id), readLines(src, warn = FALSE), fixed = TRUE))) {
      err <- c(err, sprintf("exercice %s : ancre {#%s} absente de %s", x$id, x$id, src))
    }
  }
  uniq(vapply(ct$exercises, `[[`, "", "id"), "exercices")

  # pistes : marches numérotées 1..n sans trou, badge « Marche k sur n » présent dans la page
  tr <- vapply(ct$exercises, function(x) if (is.null(x$track)) NA_character_ else x$track, "")
  for (t in unique(tr[!is.na(tr)])) {
    ex <- ct$exercises[which(tr == t)]
    st <- vapply(ex, function(x) if (is.null(x$step)) NA_integer_ else as.integer(x$step), 1L)
    if (anyNA(st) || !identical(sort(st), seq_along(ex))) {
      err <- c(err, sprintf("piste %s : les marches doivent etre numerotees 1..%d sans trou", t, length(ex))); next
    }
    for (x in ex) {
      src <- file.path(qmd_dir, sub("\\.html$", ".qmd", x$page))
      if (!file.exists(src)) next
      L <- readLines(src, warn = FALSE, encoding = "UTF-8")
      i <- grep(sprintf("{#%s}", x$id), L, fixed = TRUE)
      near <- if (length(i)) paste(L[i[1]:min(length(L), i[1] + 4)], collapse = " ") else ""
      if (!grepl(sprintf("Marche %d sur %d", as.integer(x$step), length(ex)), near, fixed = TRUE))
        err <- c(err, sprintf("exercice %s : badge « Marche %d sur %d » absent sous le titre", x$id, as.integer(x$step), length(ex)))
    }
  }
  err
}

#' Défi de la semaine : rotation déterministe (une semaine = un défi)
defi_of_week <- function(defis, date = Sys.Date()) {
  wk <- floor(as.numeric(as.Date(date) - as.Date("2026-01-05")) / 7)   # lundi 5 janvier 2026 = semaine 0
  defis[[(wk %% length(defis)) + 1]]
}

#' Assemble le JSON consommé par assets/dojo.js
build_data_json <- function(ct, veille = list(), date = Sys.Date()) {
  list(
    built = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    courses = COURSES,
    cards = ct$cards, quiz = ct$quiz, exercises = ct$exercises,
    defi = defi_of_week(ct$defis, date),
    veille = veille
  )
}
