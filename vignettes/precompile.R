# Precompile vignettes that hit the network / S3.
#
# These vignettes run read-only queries against the remote DuckDB databases,
# which is too slow and network-dependent to execute during `R CMD build`.
# Instead we knit the `*.Rmd.orig` sources ONCE here, with the code actually
# evaluated, producing plain `*.Rmd` files that have the results baked in.
# The generated `.Rmd` files are what ship in the package; they re-knit
# quickly and offline because their chunks are already static.
#
# Run this manually whenever you want to refresh the baked-in results:
#
#   Rscript vignettes/precompile.R
#
# Requires: the `ef2` package installed from current source, plus network
# access to the NCCS S3 bucket.

# Run from the package root regardless of where the script is invoked from.
orig <- list.files("vignettes", pattern = "\\.Rmd\\.orig$", full.names = TRUE)

for (src in orig) {
  out <- sub("\\.orig$", "", src)          # foo.Rmd.orig -> foo.Rmd
  message("Knitting ", src, " -> ", out)
  knitr::knit(src, output = out)
}

message("Done. Review the generated .Rmd files before committing.")
