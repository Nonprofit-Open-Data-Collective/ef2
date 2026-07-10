library(devtools)

usethis::create_package( "ef2" )


# -------------


setwd( "ef2" )
devtools::document()


setwd( ".." )

# run full checks (builds the package and runs the testthat suite,
# including the concordance currency test) before installing
devtools::check( "ef2" )

devtools::install( "ef2", dependencies=FALSE )


# -------------


library( ef2 )


# check whether the packaged concordance is current on each rebuild,
# and refresh data/concordance.rda only when it has fallen out of date
if( isFALSE( ef2::concordance_is_current() ) ){
  ef2::update_concordance()
}


# Alternatively, use the Makefile from the package root:
#   make rebuild   # document -> refresh concordance if stale -> check -> install