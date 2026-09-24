# The vectorized find_parent_nodes() / find_terminal_nodes() must return exactly
# what the original loops returned (same values, same order); only speed changed.

old_find_parent_nodes <- function(xpath_list) {
  xpath_list <- sort(xpath_list)
  parent_nodes <- character()
  seen <- list()
  for (xpath in xpath_list) {
    parts <- strsplit(xpath, "/")[[1]]
    for (i in seq_len(length(parts) - 1)) {
      parent <- paste(parts[1:i], collapse = "/")
      if (!parent %in% names(seen)) {
        parent_nodes <- c(parent_nodes, parent)
        seen[[parent]] <- TRUE
      }
    }
  }
  unique(parent_nodes)
}

old_find_terminal_nodes <- function(xpath_list) {
  xpath_list <- sort(xpath_list)
  terminal_nodes <- c()
  for (i in seq_along(xpath_list)) {
    if (i == length(xpath_list) || !startsWith(xpath_list[i + 1], paste0(xpath_list[i], "/"))) {
      terminal_nodes <- c(terminal_nodes, xpath_list[i])
    }
  }
  terminal_nodes
}

cases <- list(
  c("/Return", "/Return/A[1]", "/Return/A[1]/B", "/Return/A[10]", "/Return/A[10]/B", "/Return/A[2]", "/Return/AB"),
  "/Return",
  c("/Return", "/Return/ReturnHeader", "/Return/ReturnHeader/X", "/Return/ReturnHeaderX"),
  c("/Return/ReturnData/IRS990PF/SupplementaryInformationGrp/GrantOrContributionPdDurYrGrp[3]/Amt",
    "/Return", "/Return/ReturnData", "/Return/ReturnData/IRS990PF",
    "/Return/ReturnData/IRS990PF/SupplementaryInformationGrp",
    "/Return/ReturnData/IRS990PF/SupplementaryInformationGrp/GrantOrContributionPdDurYrGrp[3]")
)

test_that("find_parent_nodes() matches the original implementation", {
  for (x in cases) expect_identical(find_parent_nodes(x), old_find_parent_nodes(x))
})

test_that("find_terminal_nodes() matches the original implementation", {
  for (x in cases) expect_identical(find_terminal_nodes(x), old_find_terminal_nodes(x))
})

test_that("both match on a generated document-like set of xpaths", {
  set.seed(1)
  grp <- sprintf("/Return/ReturnData/IRS990PF/Grp[%d]", 1:300)
  x <- c("/Return", "/Return/ReturnData", "/Return/ReturnData/IRS990PF", grp,
         paste0(sample(grp, 600, replace = TRUE), "/", sample(c("Amt", "Nm", "Addr/City", "Addr"), 600, replace = TRUE)))
  x <- unique(x)
  expect_identical(find_parent_nodes(x), old_find_parent_nodes(x))
  expect_identical(find_terminal_nodes(x), old_find_terminal_nodes(x))
})

test_that("get_type() is fast on a large filing", {
  x <- c("/Return", "/Return/ReturnData", sprintf("/Return/ReturnData/G[%d]", 1:50000),
         sprintf("/Return/ReturnData/G[%d]/Amt", 1:50000))
  t0 <- Sys.time()
  ty <- get_type(x)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 30)
  expect_identical(sum(ty == "terminal"), 50000L)
})
