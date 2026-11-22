source(file.path("..", "..", "R", "inegalites.R"))

test_that("Gini : valeurs connues et bornes", {
  expect_equal(gini(c(1, 2, 3, 4)), 0.25)               # calcul à la main : somme|xi-xj| / (2 n^2 mu)
  expect_equal(gini(rep(5, 10)), 0)
  expect_equal(gini(c(0, 0, 0, 1)), 0.75)               # (n-1)/n pour la concentration maximale
  # un poids = une répétition
  expect_equal(gini(c(1, 2), w = c(3, 1)), gini(c(1, 1, 1, 2)))
})

test_that("Invariance d'échelle et principe des transferts (Pigou-Dalton)", {
  x <- c(10, 20, 35, 80, 200)
  for (f in list(gini, theil_T, theil_L, function(z) atkinson(z, 0.5), function(z) ge(z, 2))) {
    expect_equal(f(x), f(3.7 * x))
  }
  y <- x; y[1] <- y[1] + 5; y[5] <- y[5] - 5          # transfert progressif
  expect_lt(gini(y), gini(x))
  expect_lt(theil_T(y), theil_T(x))
  expect_lt(atkinson(y, 1), atkinson(x, 1))
})

test_that("GE : cas particuliers", {
  x <- c(10, 20, 35, 80, 200)
  mu <- mean(x)
  expect_equal(ge(x, 2), 0.5 * var(x) * (length(x) - 1) / length(x) / mu^2)  # (CV^2)/2, variance de population
  expect_equal(ge(x, 1), mean(x / mu * log(x / mu)))
  expect_equal(ge(x, 0), -mean(log(x / mu)))
  expect_equal(ge(rep(7, 4), 1), 0)
})

test_that("Atkinson : bornes et cas epsilon = 0", {
  x <- c(10, 20, 35, 80, 200)
  expect_equal(atkinson(x, 0), 0)
  a <- vapply(c(0.5, 1, 2), function(e) atkinson(x, e), numeric(1))
  expect_true(all(a > 0 & a < 1))
  expect_true(all(diff(a) > 0))                        # croissant en epsilon
  expect_equal(atkinson(x, 1), 1 - exp(mean(log(x))) / mean(x))
})

test_that("Décomposition de GE : intra + inter = total, pour plusieurs alpha", {
  set.seed(1)
  x <- rlnorm(300, 3, 0.8); g <- sample(c("a", "b", "c"), 300, TRUE)
  x[g == "b"] <- x[g == "b"] * 1.8
  for (a in c(0, 1, 2, 0.5)) {
    d <- ge_decomp(x, g, a)
    expect_equal(unname(d["total"]), ge(x, a))
    expect_equal(unname(d["intra"] + d["inter"]), ge(x, a))
  }
  w <- runif(300, 0.5, 3)                              # avec poids
  expect_equal(unname(ge_decomp(x, g, 1, w)["total"]), ge(x, 1, w))
})

test_that("Palma et Lorenz", {
  lz <- lorenz(c(1, 2, 3, 4))
  expect_equal(lz$p[c(1, nrow(lz))], c(0, 1))
  expect_equal(lz$L[c(1, nrow(lz))], c(0, 1))
  expect_equal(palma(rep(1, 100)), 0.1 / 0.4)
})
