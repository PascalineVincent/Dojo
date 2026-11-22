.PHONY: test render preview veille
test:          ## tests R, JS et exercices
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
	node tests/js/market.test.mjs
	Rscript scripts/test_exercices.R
render:        ## construit le site dans _site/
	quarto render
preview:       ## serveur local avec rechargement
	quarto preview
veille:        ## met à jour veille/items.json (réseau requis)
	Rscript scripts/update_veille.R
