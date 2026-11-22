# Le Dojo : entraînement quotidien d'économiste (Quarto + R)

Site statique (Quarto) pour **maintenir les bases** (micro L1/L2, statistiques L1, économétrie, histoire économique, économie contemporaine) et **entretenir le niveau doctoral** (mesure des inégalités, indices de ségrégation, R). Publié sur GitHub Pages (dossier `docs/`), reconstruit à la main (`quarto render`) quand tu veux rafraîchir la veille et le défi de la semaine.

## Ce que fait le site

| Page | Contenu |
|---|---|
| **Séance du jour** | 5 cartes en répétition espacée, quiz éclair, exercice du jour (pondéré par tes points faibles), veille, défi de la semaine |
| **Parcours** | Micro (laboratoire interactif), Stats, Économétrie, Histoire éco., Éco. contemporaine : exercices organisés en **pistes** |
| **Recherche** | Défi hebdomadaire ; labos Ségrégation (D, M, H, biais de petites unités, décomposition) et Inégalités (Lorenz, Gini pondéré, GE, décomposition de Theil) |
| **Veille** | Flux OpenAlex et arXiv filtré par mots-clés + socle de lectures + fiche de lecture |
| **Progression** | XP, ceintures, série, radar de maîtrise, export/import JSON |

Les exercices de code s'exécutent **dans le navigateur** (R via webR, extension [`quarto-live`](https://github.com/r-wasm/quarto-live), embarquée dans `_extensions/`). Les énoncés sont **paramétrés par la date** (graine) : les chiffres changent chaque jour, le bouton « Nouveaux énoncés » redonne un tirage.

## Démarrer

Prérequis : [Quarto](https://quarto.org) ≥ 1.4, R ≥ 4.2, Node ≥ 18 (tests).

```bash
Rscript -e 'install.packages(c("yaml","jsonlite","knitr","rmarkdown","httr2","xml2","testthat"))'
make test       # tests R + JS + exercices
make preview    # http://localhost:xxxx
```

Sous Linux/macOS, vérifie que la locale est en UTF-8 (`export LC_ALL=C.UTF-8`).

## Publier sur GitHub

```bash
git init && git add . && git commit -m "Le Dojo"
git branch -M main
git remote add origin git@github.com:<toi>/<depot>.git && git push -u origin main
```

Puis, dans le dépôt GitHub : **Settings → Pages → Build and deployment → Deploy from a branch → `main` / dossier `/docs`**. Avant le premier push, construis le site une fois en local (`quarto render`) et commite le dossier `docs/` : il contient le site publié.

Mise à jour manuelle : `Rscript scripts/update_veille.R`, puis `quarto render`, puis commit et push de `docs/` et `veille/items.json`.

Optionnel : variable de dépôt `OPENALEX_MAILTO` (ton e-mail) pour le « polite pool » d'OpenAlex.

## Organisation

```
content/            ← TOUT le contenu éditable (YAML) : flashcards, QCM, défis, catalogue d'exercices, veille
parcours/ recherche/ *.qmd   ← pages ; exercices = blocs {webr} + énoncés OJS
R/                  ← fonctions (inegalites.R, segregation.R, veille.R, dojo.R), testées
assets/             ← dojo.js (XP, SRS, QCM), lab.js (marchés), thème (SCSS/CSS)
scripts/            ← build_data.R (pre-render), update_veille.R, test_exercices.R
tests/              ← testthat, JS, test d'interface (optionnel)
```

## Ajouter du contenu

- **Une flashcard ou un QCM** : ajoute une entrée dans `content/flashcards.yml` ou `content/quiz.yml` (`id` unique et stable ; cours parmi `micro, stats, econometrie, histoire, contemporaine, recherche, r`). La validation (`scripts/build_data.R`) bloque le build en cas d'erreur.
- **Un défi de recherche** : `content/defis.yml` (rotation hebdomadaire automatique). Chaque défi doit avoir son corrigé dans `recherche/defis.qmd`, sous un titre `{#id-du-defi}` (vérifié par `validate_content`) ; le code est exécuté au rendu avec des `stopifnot()`.
- **Un exercice** : copie une section existante d'une page `.qmd` (badge `[Marche k sur n · mode]{.dojo-step}`, cellule OJS qui tire les paramètres, énoncé, blocs `{webr}` gabarit / **deux indices** / solution / correction, `{.dojo-done}`), puis déclare-le dans `content/exercices.yml` (`id` = ancre de la section ; `track` et `step` pour l'insérer dans une piste). Le **corrigé détaillé** est le bloc `.solution` : `**Raisonnement.**` avant le code, `**Pièges fréquents.**` et `**Pour aller plus loin.**` après. `make test` exécute la solution et la correction sur 30 tirages, vérifie qu'une mauvaise réponse est refusée, que les deux indices et les rubriques du corrigé sont présents, et que les marches d'une piste sont numérotées sans trou.
- **Les thèmes de veille** : `content/veille_config.yml` (requêtes, mots-clés pondérés, fenêtre de dates).

Piège de syntaxe : n'écris pas une interpolation OJS `${...}` et une formule LaTeX `$...$` dans le même paragraphe.

## Limites à connaître

- **Progression stockée dans le navigateur** (`localStorage`) : exporte-la depuis « Progression » pour la sauvegarder ou la transférer ; changer de navigateur ou vider les données l'efface.
- **webR** : seuls les paquets disponibles pour WebAssembly sont utilisables (les exercices n'emploient que `base`). Les paquets lourds (`sf`, `fixest`...) sont à utiliser en local ; les fonctions de `R/` fonctionnent aussi hors navigateur.
- Les réponses des exercices sont corrigées dans le navigateur : elles sont donc consultables par n'importe qui lisant le code de la page. C'est un outil d'entraînement personnel, pas un examen.
- Le premier chargement d'une page d'exercices télécharge webR (quelques secondes).

## Licences

Code du Dojo : MIT. `_extensions/r-wasm/live` : extension `quarto-live` (MIT, voir son fichier de licence).


## Pistes d'exercices

Chaque thème est une **piste** de marches ordonnées : *Guidé* (un ou deux trous, formule suggérée), *À compléter* (une fonction à terminer), *Autonome* (tu écris la logique, la correction teste des cas limites). L'exercice du jour ne propose une marche que si les précédentes de sa piste ont été réussies. Pistes actuelles : concurrence parfaite, pouvoir de marché, estimation et simulation, économétrie, dette publique, ségrégation, inégalités.
Dans chaque exercice : bouton **Hint** (indice 1 : par où commencer, puis indice 2 : la formule), puis **Solution** avec le corrigé détaillé.
