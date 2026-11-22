# ==============================================================================
# Mesures d'inégalités  (fonctions pures, sans dépendance : tournent aussi dans
# le navigateur via webR)
#
# Conventions : x = vecteur de revenus (>= 0), w = poids (optionnels, >= 0).
# Les poids sont normalisés en parts de population.
# ==============================================================================

.prep_xw <- function(x, w = NULL) {
  if (is.null(w)) w <- rep(1, length(x))
  stopifnot(length(x) == length(w), !anyNA(x), !anyNA(w), all(w >= 0), any(w > 0))
  keep <- w > 0
  list(x = x[keep], w = w[keep] / sum(w[keep]))
}

#' Courbe de Lorenz (points de rupture), de (0,0) à (1,1)
lorenz <- function(x, w = NULL) {
  p <- .prep_xw(x, w)
  stopifnot(all(p$x >= 0))
  o <- order(p$x)
  x <- p$x[o]; w <- p$w[o]
  data.frame(p = c(0, cumsum(w)),
             L = c(0, cumsum(w * x) / sum(w * x)))
}

#' Indice de Gini = 1 - 2 * aire sous la courbe de Lorenz (règle des trapèzes)
gini <- function(x, w = NULL) {
  lz <- lorenz(x, w)
  n <- nrow(lz)
  1 - sum(diff(lz$p) * (lz$L[-1] + lz$L[-n]))
}

#' Famille d'entropie généralisée GE(alpha)
#' alpha = 0 : écart logarithmique moyen (MLD) ; alpha = 1 : Theil T ; alpha = 2 : (CV^2)/2
ge <- function(x, alpha, w = NULL) {
  p <- .prep_xw(x, w)
  x <- p$x; w <- p$w
  stopifnot(all(x >= 0), sum(w * x) > 0)
  if (alpha <= 0) stopifnot(all(x > 0))
  mu <- sum(w * x)
  r <- x / mu
  if (alpha == 0) {
    -sum(w * log(r))
  } else if (alpha == 1) {
    sum(w * ifelse(r > 0, r * log(r), 0))
  } else {
    (sum(w * r^alpha) - 1) / (alpha * (alpha - 1))
  }
}

theil_T <- function(x, w = NULL) ge(x, 1, w)
theil_L <- function(x, w = NULL) ge(x, 0, w)   # MLD, dit aussi Theil L

#' Indice d'Atkinson d'aversion epsilon (epsilon >= 0)
atkinson <- function(x, epsilon, w = NULL) {
  p <- .prep_xw(x, w)
  x <- p$x; w <- p$w
  stopifnot(epsilon >= 0, all(x >= 0))
  if (epsilon >= 1) stopifnot(all(x > 0))
  mu <- sum(w * x)
  if (epsilon == 1) {
    1 - exp(sum(w * log(x))) / mu
  } else {
    1 - sum(w * (x / mu)^(1 - epsilon))^(1 / (1 - epsilon))
  }
}

#' Rapport de Palma : part des 10 % les plus riches / part des 40 % les plus pauvres
#' (courbe de Lorenz interpolée linéairement entre ses points de rupture)
palma <- function(x, w = NULL) {
  lz <- lorenz(x, w)
  L <- function(q) approx(lz$p, lz$L, xout = q)$y
  (1 - L(0.9)) / L(0.4)
}

#' Décomposition de GE(alpha) en inégalités intra et inter-groupes (additive)
#'   intra = sum_g f_g^(1-alpha) * s_g^alpha * GE_g   (f = part de pop., s = part de revenu)
#'   inter = GE(alpha) de la distribution où chacun reçoit la moyenne de son groupe
ge_decomp <- function(x, g, alpha, w = NULL) {
  p <- .prep_xw(x, w)
  keep <- if (is.null(w)) rep(TRUE, length(x)) else w > 0
  g <- g[keep]
  x <- p$x; w <- p$w
  mu <- sum(w * x)
  grp <- split(seq_along(x), g)
  f  <- vapply(grp, function(i) sum(w[i]), numeric(1))
  mg <- vapply(grp, function(i) sum(w[i] * x[i]) / sum(w[i]), numeric(1))
  s  <- f * mg / mu
  ge_g <- vapply(grp, function(i) ge(x[i], alpha, w[i]), numeric(1))
  intra <- if (alpha == 0) sum(f * ge_g)
           else if (alpha == 1) sum(s * ge_g)
           else sum(f^(1 - alpha) * s^alpha * ge_g)
  inter <- ge(mg, alpha, f)
  c(total = intra + inter, intra = intra, inter = inter,
    part_inter = inter / (intra + inter))
}
