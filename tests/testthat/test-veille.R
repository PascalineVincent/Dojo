source(file.path("..", "..", "R", "dojo.R"))
source(file.path("..", "..", "R", "veille.R"))
cfg <- read_yaml_utf8(file.path("..", "..", "content", "veille_config.yml"))

test_that("OpenAlex : reconstitution du résumé et parsing", {
  expect_equal(oa_abstract(list(We = list(0), study = list(1), segregation = list(2, 3))),
               "We study segregation segregation")
  expect_equal(oa_abstract(NULL), "")
  r <- oa_parse(jsonlite::fromJSON(file.path("fixtures", "openalex.json"), simplifyVector = FALSE))
  expect_length(r, 2)
  expect_equal(r[[1]]$authors, c("Auteur A", "Auteur B"))
  expect_equal(r[[1]]$venue, "Journal de test")
  expect_match(r[[1]]$abstract, "segregation and inequality measures segregation decomposition")
  expect_equal(r[[2]]$venue, "")                      # champs manquants tolérés
  expect_equal(r[[2]]$id, "https://openalex.org/W0000002")
})

test_that("arXiv : parsing Atom", {
  r <- arxiv_parse(paste(readLines(file.path("fixtures", "arxiv.xml")), collapse = "\n"))
  expect_length(r, 1)
  expect_equal(r[[1]]$title, "Fixture: Income inequality and the Gini coefficient")
  expect_equal(r[[1]]$date, "2026-11-15")
  expect_equal(r[[1]]$source, "arxiv")
})

test_that("Scoring : thèmes, poids titre x2", {
  it <- list(title = "Residential segregation and the mutual information index",
             abstract = "dissimilarity and neighborhood")
  s <- score_item(it, cfg$topics[[1]]$keywords)
  # segregation (3*2) + mutual information (3*2) + dissimilarity (3*1) + neighborhood (1*1) + residential (1*2)
  expect_equal(s$score, 6 + 6 + 3 + 1 + 2)
  expect_true(all(c("segregation", "mutual information") %in% s$matched))
  r <- score_items(list(it), cfg$topics)
  expect_equal(r[[1]]$topic, "Ségrégation")
  expect_null(r[[1]]$abstract)                         # le résumé n'est pas conservé
})

test_that("Thème « Identité de genre » : détection et rattachement", {
  it <- list(title = "Gender identity and labor market outcomes of transgender workers",
             abstract = "We study non-binary and gender minority workers.")
  r <- score_items(list(it), cfg$topics)
  expect_equal(r[[1]]$topic, "Identité de genre")
  expect_gte(r[[1]]$score, cfg$min_score)
  expect_true(any(vapply(cfg$topics, function(t) t$name == "Identité de genre" && length(t$queries) >= 3, TRUE)))
})

test_that("Fusion : dédoublonnage, filtre date et score, tri", {
  mk <- function(id, date, score) list(id = id, date = date, score = score)
  old <- list(mk("a", "2026-11-01", 5), mk("b", "2026-01-01", 9))   # b trop ancien
  new <- list(mk("a", "2026-11-01", 5), mk("c", "2026-11-20", 8), mk("d", "2026-11-20", 1))  # d score faible
  m <- merge_items(old, new, min_score = 2, since = as.Date("2026-11-01"), max_items = 10)
  expect_equal(vapply(m, `[[`, "", "id"), c("c", "a"))
  expect_length(merge_items(old, new, 2, as.Date("2026-11-01"), max_items = 1), 1)
  expect_equal(merge_items(list(), list(), 2, Sys.Date(), 5), list())
})
