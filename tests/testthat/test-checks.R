source(file.path("..", "..", "R", "checks.R"))

toy <- function(...) tibble::tibble(...)

test_that("range check flags bounded percentages only", {
  d <- toy(indicator = c("CR.1", "GER.1", "NERT.1.CP"), iso3 = "AAA", year = 2020L,
           value = c(101, 120, -1))
  f <- check_range(d)
  expect_setequal(f$indicator, c("CR.1", "NERT.1.CP"))   # GER may exceed 100
})

test_that("out-of-school identity is checked with tolerance", {
  d <- toy(indicator = c("ROFST.1.CP", "NERT.1.CP", "ROFST.1.CP", "NERT.1.CP"),
           iso3 = c("AAA", "AAA", "BBB", "BBB"), year = 2020L, value = c(10, 90.3, 10, 85))
  f <- check_oos_identity(d)
  expect_equal(f$iso3, "BBB")
})

test_that("total outside female/male bracket is flagged", {
  d <- toy(indicator = rep(c("GER.1", "GER.1.F", "GER.1.M"), 2), iso3 = rep(c("AAA", "BBB"), each = 3),
           year = 2020L, value = c(100, 99, 101, 110, 99, 101))
  expect_equal(check_sex_bracket(d)$iso3, "BBB")
})

test_that("jumps respect threshold and gap length", {
  d <- toy(indicator = "CR.1", iso3 = "AAA", year = c(2010L, 2011L, 2015L), value = c(50, 65, 90))
  f <- check_jumps(d, threshold = 10)
  expect_equal(f$year, 2011L)          # 2011 -> 2015 is a four-year gap, not checked
})

test_that("coverage counts missing years", {
  d <- toy(indicator = "CR.1", iso3 = "AAA", year = c(2015L, 2016L), value = c(1, NA))
  cv <- coverage(d, "AAA", "CR.1", 2015:2018)
  expect_equal(cv$share, 0.25)
  expect_equal(cv$latest, 2015)
})
