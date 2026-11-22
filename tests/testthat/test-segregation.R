source(file.path("..", "..", "R", "segregation.R"))

separe   <- cbind(A = c(10, 0), B = c(0, 10))
integre  <- cbind(A = c(10, 20), B = c(5, 10))          # même composition (2/3, 1/3) partout

test_that("D de Duncan : bornes", {
  expect_equal(seg_D(separe), 1)
  expect_equal(seg_D(integre), 0)
  # valeur calculée à la main : parts A = (.5,.5), parts B = (.25,.75) -> D = .5*(.25+.25)
  expect_equal(seg_D(cbind(A = c(10, 10), B = c(5, 15))), 0.25)
})

test_that("M et H : bornes", {
  expect_equal(seg_M(integre), 0)
  expect_equal(seg_M(separe), log(2))                    # M = E quand les groupes sont séparés
  expect_equal(seg_H(separe), 1)
  expect_equal(seg_H(integre), 0)
})

test_that("M = formule directe en triple somme", {
  set.seed(3)
  tab <- matrix(rpois(5 * 3, 20) + 1, 5, 3)
  N <- sum(tab); ti <- rowSums(tab) / N; pg <- colSums(tab) / N
  direct <- sum(outer(seq_len(5), seq_len(3), Vectorize(function(i, g)
    tab[i, g] / N * log((tab[i, g] / N) / (ti[i] * pg[g])))))
  expect_equal(seg_M(tab), direct)
})

test_that("Invariances de M : échelle, équivalence organisationnelle, transfert de groupes", {
  set.seed(4)
  tab <- matrix(rpois(6 * 3, 15) + 1, 6, 3)
  expect_equal(seg_M(tab), seg_M(7 * tab))               # invariance d'échelle (insensible à la taille totale)
  # scinder une unité en deux de même composition ne change pas M
  split_tab <- rbind(tab[-1, ], tab[1, ] / 2, tab[1, ] / 2)
  expect_equal(seg_M(tab), seg_M(split_tab))
  # symétrie : invariance à l'ordre des unités et des groupes
  expect_equal(seg_M(tab[sample(6), ]), seg_M(tab))
  expect_equal(seg_M(tab[, c(3, 1, 2)]), seg_M(tab))
})

test_that("Décomposition entre/intra de M : identité exacte", {
  set.seed(5)
  tab  <- matrix(rpois(12 * 3, 12) + 1, 12, 3)
  zone <- rep(c("nord", "sud", "est"), each = 4)
  d <- seg_M_decomp(tab, zone)
  expect_equal(unname(d["total"]), seg_M(tab))
  expect_equal(unname(d["inter"] + d["intra"]), seg_M(tab))
  expect_gte(d[["inter"]], 0); expect_gte(d[["intra"]], 0)
})

test_that("Isolement : bornes", {
  expect_equal(seg_isolation(separe, "A"), 1)
  expect_equal(seg_isolation(integre, "B"), 1 / 3)       # = part globale du groupe B si pas de ségrégation
})

test_that("Biais de petites unités : D > 0 sous allocation aléatoire", {
  tab <- seg_sim_city(U = 200, size = 5, p = 0.3, kappa = Inf, seed = 10)  # aucune ségrégation structurelle
  null_D <- seg_null(tab, B = 50, stat = seg_D, seed = 11)
  expect_gt(mean(null_D), 0.1)                            # mais D observé est loin de 0 : biais
  # avec de grandes unités, le biais disparaît
  big <- seg_sim_city(U = 20, size = 5000, p = 0.3, kappa = Inf, seed = 10)
  expect_lt(mean(seg_null(big, B = 50, stat = seg_D, seed = 11)), 0.03)
})

test_that("Ville synthétique : kappa pilote la ségrégation", {
  h <- function(k) seg_H(seg_sim_city(100, 200, 0.3, k, seed = 42))
  expect_gt(h(1), h(10)); expect_gt(h(10), h(100)); expect_gt(h(100), h(Inf) - 1e-9)
})

test_that("seg_null conserve marges", {
  tab <- matrix(c(30, 10, 5, 25, 40, 20), 3, 2)
  U <- nrow(tab); G <- ncol(tab)
  set.seed(1)
  unit_id <- rep(seq_len(U), rowSums(tab)); labels <- rep(seq_len(G), colSums(tab))
  lab <- sample(labels)
  m <- matrix(tabulate(unit_id + U * (lab - 1L), nbins = U * G), U, G)
  expect_equal(rowSums(m), rowSums(tab)); expect_equal(colSums(m), colSums(tab))
})
