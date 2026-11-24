# Quality checks on published SDG 4 series.
# Each check returns flags in one shape: check, indicator, iso3, year, value, detail.
# A flag is a prompt to look closer, not a verdict that the number is wrong.

BOUNDED_PCT <- c("CR", "NERT", "ROFST", "TRTP")   # must lie in 0-100

family <- function(indicator) sub("\\..*$", "", indicator)

empty_flags <- function() {
  tibble::tibble(check = character(), indicator = character(), iso3 = character(),
                 year = integer(), value = double(), detail = character())
}

#' Percentages outside 0-100 (GER is excluded: it can exceed 100 by definition).
check_range <- function(df) {
  df |>
    dplyr::filter(family(indicator) %in% BOUNDED_PCT, value < 0 | value > 100) |>
    dplyr::transmute(check = "range", indicator, iso3, year, value,
                     detail = sprintf("%.1f is outside 0-100", value))
}

#' Out-of-school rate should equal 100 minus the total net enrolment rate.
check_oos_identity <- function(df, tol = 0.5) {
  w <- df |>
    dplyr::filter(indicator %in% c("ROFST.1.CP", "NERT.1.CP")) |>
    dplyr::select(indicator, iso3, year, value) |>
    tidyr::pivot_wider(names_from = indicator, values_from = value)
  if (!all(c("ROFST.1.CP", "NERT.1.CP") %in% names(w))) return(empty_flags())
  w |>
    dplyr::filter(!is.na(.data[["ROFST.1.CP"]]), !is.na(.data[["NERT.1.CP"]]),
                  abs(.data[["ROFST.1.CP"]] + .data[["NERT.1.CP"]] - 100) > tol) |>
    dplyr::transmute(check = "oos_identity", indicator = "ROFST.1.CP", iso3, year,
                     value = .data[["ROFST.1.CP"]],
                     detail = sprintf("out-of-school %.1f + net enrolment %.1f = %.1f, not 100",
                                      .data[["ROFST.1.CP"]], .data[["NERT.1.CP"]],
                                      .data[["ROFST.1.CP"]] + .data[["NERT.1.CP"]]))
}

#' A both-sexes value should lie between the female and male values.
check_sex_bracket <- function(df, base = "GER.1", tol = 0.5) {
  ids <- c(base, paste0(base, ".F"), paste0(base, ".M"))
  w <- df |>
    dplyr::filter(indicator %in% ids) |>
    dplyr::select(indicator, iso3, year, value) |>
    tidyr::pivot_wider(names_from = indicator, values_from = value)
  if (!all(ids %in% names(w))) return(empty_flags())
  t <- w[[ids[1]]]; f <- w[[ids[2]]]; m <- w[[ids[3]]]
  bad <- !is.na(t) & !is.na(f) & !is.na(m) & (t < pmin(f, m) - tol | t > pmax(f, m) + tol)
  w[bad, ] |>
    dplyr::transmute(check = "sex_bracket", indicator = base, iso3, year, value = t[bad],
                     detail = sprintf("total %.1f outside female %.1f / male %.1f", t[bad], f[bad], m[bad]))
}

#' Year-on-year changes larger than `threshold` points (consecutive or one-year gaps).
check_jumps <- function(df, threshold = 10, families = c("CR", "GER", "NERT", "ROFST", "TRTP")) {
  df |>
    dplyr::filter(family(indicator) %in% families, !is.na(value)) |>
    dplyr::arrange(indicator, iso3, year) |>
    dplyr::group_by(indicator, iso3) |>
    dplyr::mutate(prev = dplyr::lag(value), prev_year = dplyr::lag(year)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(prev), year - prev_year <= 2, abs(value - prev) > threshold) |>
    dplyr::transmute(check = "jump", indicator, iso3, year, value,
                     detail = sprintf("%+.1f points since %d (%.1f -> %.1f)",
                                      value - prev, prev_year, prev, value))
}

run_checks <- function(df) {
  dplyr::bind_rows(check_range(df), check_oos_identity(df), check_sex_bracket(df), check_jumps(df))
}

#' Share of country-years with a value, per indicator and country.
coverage <- function(df, countries, indicators, years) {
  grid <- tidyr::expand_grid(indicator = indicators, iso3 = countries, year = years)
  grid |>
    dplyr::left_join(dplyr::distinct(df, indicator, iso3, year, has = !is.na(value)),
                     by = c("indicator", "iso3", "year")) |>
    dplyr::mutate(has = dplyr::coalesce(has, FALSE)) |>
    dplyr::summarise(share = mean(has), latest = suppressWarnings(max(year[has])),
                     .by = c(indicator, iso3)) |>
    dplyr::mutate(latest = ifelse(is.finite(latest), latest, NA_integer_))
}

#' Latest available value per indicator and country.
latest_value <- function(df) {
  df |>
    dplyr::filter(!is.na(value)) |>
    dplyr::slice_max(year, n = 1, by = c(indicator, iso3), with_ties = FALSE)
}
