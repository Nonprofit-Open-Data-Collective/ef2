test_that("packaged concordance matches the GitHub master", {
  skip_on_cran()

  current <- concordance_is_current( verbose = FALSE )

  # Network unavailable (offline) -> can't judge currency, so skip.
  skip_if( is.na( current ),
           "GitHub concordance could not be retrieved (offline?)." )

  expect_true(
    current,
    info = "Packaged data/concordance.rda is out of date. Run update_concordance() to refresh."
  )
})
