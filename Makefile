# Makefile for the ef2 package.
#
# Requires `make` (bundled with Rtools on Windows) plus the devtools /
# roxygen2 toolchain. Run targets from the package root, e.g.:
#
#   make rebuild     # document -> refresh concordance if stale -> check -> install
#   make check       # R CMD check via devtools (runs the testthat suite)
#   make concordance # refresh data/concordance.rda from GitHub only if out of date
#
# `make check` runs tests/testthat/test-concordance.R, which fails when the
# packaged concordance is out of date -- so the currency check and the test
# both fire during a full rebuild.

RSCRIPT := Rscript

.PHONY: all rebuild document concordance test check install clean

all: rebuild

## rebuild : document, refresh concordance if stale, check (runs tests), install
rebuild: document concordance check install

## document : regenerate NAMESPACE and man/ from roxygen comments
document:
	$(RSCRIPT) -e "roxygen2::roxygenise()"

## concordance : refresh data/concordance.rda from GitHub only if out of date
concordance:
	$(RSCRIPT) -e "if (requireNamespace('ef2', quietly=TRUE) && isFALSE(ef2::concordance_is_current())) ef2::update_concordance()"

## test : run the testthat suite (incl. the concordance currency test)
test:
	$(RSCRIPT) -e "devtools::test()"

## check : run R CMD check via devtools (builds and runs tests)
check:
	$(RSCRIPT) -e "devtools::check()"

## install : install the package without re-installing dependencies
install:
	$(RSCRIPT) -e "devtools::install(dependencies = FALSE)"

## clean : remove build artifacts (check dirs and tarballs)
clean:
	$(RSCRIPT) -e "unlink(c('ef2.Rcheck','../ef2.Rcheck'), recursive=TRUE); f <- Sys.glob(c('ef2_*.tar.gz','../ef2_*.tar.gz')); if (length(f)) file.remove(f)"
