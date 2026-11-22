source(file.path("..", "..", "R", "dojo.R"))
root <- file.path("..", "..")

test_that("Contenu : valide et cohérent", {
  ct <- read_content(file.path(root, "content"))
  expect_equal(validate_content(ct, qmd_dir = root), character())
  expect_gt(length(ct$cards), 50)
})

test_that("validate_content détecte les erreurs", {
  ct <- read_content(file.path(root, "content"))
  bad <- ct; bad$cards[[2]]$id <- bad$cards[[1]]$id
  expect_match(paste(validate_content(bad, qmd_dir = root), collapse = " "), "en double")
  bad <- ct; bad$quiz[[1]]$answer <- 99
  expect_match(paste(validate_content(bad, qmd_dir = root), collapse = " "), "hors bornes")
  bad <- ct; bad$cards[[1]]$course <- "astrologie"
  expect_match(paste(validate_content(bad, qmd_dir = root), collapse = " "), "cours inconnu")
  bad <- ct; bad$exercises[[1]]$id <- "ancre-inexistante"
  expect_match(paste(validate_content(bad, qmd_dir = root), collapse = " "), "ancre")
})

test_that("Défi de la semaine : rotation déterministe", {
  ct <- read_content(file.path(root, "content"))
  n <- length(ct$defis)
  d0 <- defi_of_week(ct$defis, "2026-01-05")
  expect_equal(d0$id, ct$defis[[1]]$id)
  expect_equal(defi_of_week(ct$defis, "2026-01-11")$id, d0$id)           # même semaine (dimanche)
  expect_equal(defi_of_week(ct$defis, "2026-01-12")$id, ct$defis[[2]]$id)
  expect_equal(defi_of_week(ct$defis, as.Date("2026-01-05") + 7 * n)$id, d0$id)   # cycle complet
})
