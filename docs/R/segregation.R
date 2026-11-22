# ==============================================================================
# Indices de ségrégation
#
# Entrée commune : `tab` = matrice (ou data.frame) d'effectifs, lignes = unités
# (quartiers, écoles...), colonnes = groupes. Les noms de colonnes sont libres.
# ==============================================================================

.as_tab <- function(tab) {
  tab <- as.matrix(tab)
  stopifnot(is.numeric(tab), !anyNA(tab), all(tab >= 0), sum(tab) > 0)
  tab[rowSums(tab) > 0, , drop = FALSE]
}

.entropy <- function(p) {            # entropie de Shannon (log naturel), 0 log 0 = 0
  p <- p[p > 0]
  -sum(p * log(p))
}

#' Indice de dissimilarité de Duncan (deux groupes) : 0 = intégration, 1 = séparation totale
seg_D <- function(tab) {
  tab <- .as_tab(tab)
  stopifnot(ncol(tab) == 2)
  0.5 * sum(abs(tab[, 1] / sum(tab[, 1]) - tab[, 2] / sum(tab[, 2])))
}

#' Entropie de la composition globale E (plafond de M)
seg_E <- function(tab) {
  tab <- .as_tab(tab)
  .entropy(colSums(tab) / sum(tab))
}

#' Indice d'information mutuelle M (Theil & Finizza 1971 ; Mora & Ruiz-Castillo 2011)
#' M = E - sum_i t_i E_i  (t_i = part de l'unité i dans la population)
#' Multigroupe, décomposable, insensible aux marges (cf. Frankel & Volij 2011).
seg_M <- function(tab) {
  tab <- .as_tab(tab)
  t_i <- rowSums(tab) / sum(tab)
  E_i <- apply(tab / rowSums(tab), 1, .entropy)
  seg_E(tab) - sum(t_i * E_i)
}

#' Indice de ségrégation de Theil normalisé H = M / E  (Reardon & Firebaugh 2002), dans [0, 1]
seg_H <- function(tab) {
  e <- seg_E(tab)
  if (e == 0) return(NA_real_)
  seg_M(tab) / e
}

#' Indice d'isolement du groupe g : probabilité qu'un membre de g ait pour voisin un membre de g
#' (colonne `g`, nom ou indice)
seg_isolation <- function(tab, g = 1) {
  tab <- .as_tab(tab)
  sum((tab[, g] / sum(tab[, g])) * (tab[, g] / rowSums(tab)))
}

#' Décomposition de M entre/intra grandes zones : M = M_inter + sum_r (N_r / N) * M_r
#' `zone` = vecteur (longueur = nombre d'unités de `tab`) donnant la zone de chaque unité.
#' Attention : les unités vides sont retirées ; passer une matrice sans ligne nulle.
seg_M_decomp <- function(tab, zone) {
  tab <- as.matrix(tab)
  stopifnot(nrow(tab) == length(zone), all(rowSums(tab) > 0))
  agg   <- rowsum(tab, group = zone)
  M_inter <- seg_M(agg)
  idx   <- split(seq_len(nrow(tab)), zone)
  N_r   <- vapply(idx, function(i) sum(tab[i, ]), numeric(1))
  M_r   <- vapply(idx, function(i) seg_M(tab[i, , drop = FALSE]), numeric(1))
  intra <- sum(N_r / sum(N_r) * M_r)
  c(total = M_inter + intra, inter = M_inter, intra = intra)
}

#' Distribution de `stat` sous allocation aléatoire : on conserve la taille des unités et la
#' composition globale, mais on redistribue les individus au hasard. Sert de benchmark au
#' biais de petites unités (un indice n'est jamais nul en échantillon fini).
seg_null <- function(tab, B = 200, stat = seg_M, seed = NULL) {
  tab <- .as_tab(tab)
  stopifnot(all(tab == round(tab)))
  if (!is.null(seed)) set.seed(seed)
  U <- nrow(tab); G <- ncol(tab)
  unit_id <- rep(seq_len(U), rowSums(tab))
  labels  <- rep(seq_len(G), colSums(tab))
  vapply(seq_len(B), function(b) {
    lab <- sample(labels)
    stat(matrix(tabulate(unit_id + U * (lab - 1L), nbins = U * G), U, G))
  }, numeric(1))
}

#' Ville synthétique à deux groupes : `U` unités de `size` habitants. La part du groupe B dans
#' l'unité i suit une loi Beta de moyenne `p` et de concentration `kappa` : kappa = Inf donne
#' une ville sans ségrégation « structurelle » ; kappa petit donne des quartiers homogènes.
seg_sim_city <- function(U = 100, size = 200, p = 0.3, kappa = 5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  q <- if (is.infinite(kappa)) rep(p, U) else rbeta(U, p * kappa, (1 - p) * kappa)
  b <- rbinom(U, size, q)
  cbind(A = size - b, B = b)
}
