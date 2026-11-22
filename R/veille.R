# ==============================================================================
# Veille documentaire : collecte (OpenAlex, arXiv), scoring par mots-clés, fusion.
# Les fonctions de parsing sont pures (testées sur fixtures) ; seules fetch_*()
# touchent au réseau.
# ==============================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- OpenAlex ----------------------------------------------------------------

#' Reconstitue un résumé à partir de abstract_inverted_index (mot -> positions)
oa_abstract <- function(idx) {
  if (is.null(idx) || length(idx) == 0) return("")
  words <- rep("", max(unlist(idx)) + 1L)
  for (w in names(idx)) words[unlist(idx[[w]]) + 1L] <- w
  trimws(gsub("\\s+", " ", paste(words, collapse = " ")))
}

#' Transforme la réponse OpenAlex (liste R issue de jsonlite::fromJSON(simplifyVector = FALSE))
oa_parse <- function(resp) {
  lapply(resp$results %||% list(), function(w) {
    au <- vapply(w$authorships %||% list(), function(a) a$author$display_name %||% "", "")
    list(
      id = w$doi %||% w$id,
      title = w$title %||% "",
      authors = au[nzchar(au)],
      venue = w$primary_location$source$display_name %||% "",
      date = w$publication_date %||% "",
      url = w$doi %||% w$id,
      abstract = oa_abstract(w$abstract_inverted_index),
      source = "openalex"
    )
  })
}

fetch_openalex <- function(query, from, per_page = 25, mailto = Sys.getenv("OPENALEX_MAILTO")) {
  req <- httr2::request("https://api.openalex.org/works") |>
    httr2::req_url_query(
      search = query,
      filter = paste0("from_publication_date:", from),
      sort = "relevance_score:desc", `per-page` = per_page,
      select = "id,doi,title,publication_date,authorships,primary_location,abstract_inverted_index"
    ) |>
    httr2::req_user_agent("dojo-veille (https://github.com)") |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_timeout(30)
  if (nzchar(mailto)) req <- httr2::req_url_query(req, mailto = mailto)
  oa_parse(httr2::resp_body_json(httr2::req_perform(req)))
}

# ---- arXiv -------------------------------------------------------------------

arxiv_parse <- function(xml_text) {
  doc <- xml2::read_xml(xml_text)
  xml2::xml_ns_strip(doc)
  lapply(xml2::xml_find_all(doc, "//entry"), function(e) {
    txt <- function(path) trimws(gsub("\\s+", " ", xml2::xml_text(xml2::xml_find_first(e, path))))
    id <- txt("./id")
    list(id = id, title = txt("./title"),
         authors = xml2::xml_text(xml2::xml_find_all(e, "./author/name")),
         venue = "arXiv", date = substr(txt("./published"), 1, 10),
         url = id, abstract = txt("./summary"), source = "arxiv")
  })
}

fetch_arxiv <- function(categories, max_results = 100) {
  q <- paste0("cat:", categories, collapse = "+OR+")
  url <- paste0("https://export.arxiv.org/api/query?search_query=", q,
                "&sortBy=submittedDate&sortOrder=descending&max_results=", max_results)
  resp <- httr2::request(url) |> httr2::req_user_agent("dojo-veille") |>
    httr2::req_retry(max_tries = 3) |> httr2::req_timeout(30) |> httr2::req_perform()
  arxiv_parse(httr2::resp_body_string(resp))
}

# ---- Scoring -----------------------------------------------------------------

#' Score d'un item pour un thème : somme des poids des mots-clés trouvés
#' (titre = poids x 2, résumé = poids x 1 ; chaque mot-clé compté une fois par champ).
score_item <- function(item, keywords) {
  kw <- unlist(keywords)
  title <- tolower(item$title); abs <- tolower(item$abstract %||% "")
  hit <- vapply(names(kw), function(k) {
    k <- tolower(k)
    kw[[k]] * (2 * grepl(k, title, fixed = TRUE) + 1 * grepl(k, abs, fixed = TRUE))
  }, numeric(1))
  list(score = sum(hit), matched = names(kw)[hit > 0])
}

#' Attribue à chaque item son meilleur thème et son score ; retire le résumé (non stocké)
score_items <- function(items, topics) {
  lapply(items, function(it) {
    best <- list(score = -1)
    for (tp in topics) {
      s <- score_item(it, tp$keywords)
      if (s$score > best$score) best <- c(s, list(topic = tp$name))
    }
    it$abstract <- NULL
    it$score <- best$score; it$topic <- best$topic; it$matched <- as.list(best$matched)
    it
  })
}

#' Fusion avec les items existants : dédoublonnage par id, filtre date/score, tri, plafond
merge_items <- function(old, new, min_score = 2, since = Sys.Date() - 21, max_items = 60) {
  all <- c(new, old)
  ids <- vapply(all, function(x) x$id %||% "", "")
  all <- all[!duplicated(ids) & nzchar(ids)]
  ok <- vapply(all, function(x) {
    d <- suppressWarnings(as.Date(x$date))
    !is.na(d) && d >= since && x$score >= min_score
  }, logical(1))
  all <- all[ok]
  if (!length(all)) return(list())
  ord <- order(-vapply(all, `[[`, numeric(1), "score"),
               -as.numeric(as.Date(vapply(all, `[[`, "", "date"))))
  head(all[ord], max_items)
}
