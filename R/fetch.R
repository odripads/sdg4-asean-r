# Download SDG 4 indicators from the UIS public data API (no key needed).
# https://api.uis.unesco.org/api/public/documentation/
#
# Every download records the UIS data version and download time, so a
# result can always be traced to the release it came from.

UIS_API <- "https://api.uis.unesco.org/api/public"

uis_version <- function() {
  resp <- httr2::request(UIS_API) |>
    httr2::req_url_path_append("versions", "default") |>
    httr2::req_user_agent("sdg4-asean-r (research; R httr2)") |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)$version
}

#' Fetch indicator values for countries and years.
#' Returns one row per indicator x country x year, with UIS qualifiers kept.
uis_fetch <- function(indicators, geo_units, start = 2010, end = NULL) {
  req <- httr2::request(UIS_API) |>
    httr2::req_url_path_append("data", "indicators") |>
    httr2::req_user_agent("sdg4-asean-r (research; R httr2)") |>
    httr2::req_retry(max_tries = 4, backoff = function(i) 2^i) |>
    httr2::req_throttle(rate = 2)                         # stay polite to the API
  query <- c(
    stats::setNames(as.list(indicators), rep("indicator", length(indicators))),
    stats::setNames(as.list(geo_units), rep("geoUnit", length(geo_units))),
    list(start = start, indicatorMetadata = "false")
  )
  if (!is.null(end)) query$end <- end
  req <- do.call(httr2::req_url_query, c(list(req), query))
  body <- httr2::resp_body_json(httr2::req_perform(req), simplifyVector = TRUE)
  recs <- body$records
  if (length(recs) == 0 || nrow(recs) == 0) {
    return(tibble::tibble(indicator = character(), iso3 = character(), year = integer(),
                          value = double(), magnitude = character(), qualifier = character()))
  }
  tibble::tibble(
    indicator = recs$indicatorId,
    iso3 = recs$geoUnit,
    year = as.integer(recs$year),
    value = as.double(recs$value),
    magnitude = as.character(recs$magnitude),
    qualifier = as.character(recs$qualifier)
  )
}

#' Fetch in chunks (one call per indicator) and save a dated snapshot.
uis_snapshot <- function(indicators, geo_units, start, path) {
  version <- uis_version()
  out <- purrr::map(indicators, \(i) uis_fetch(i, geo_units, start)) |> purrr::list_rbind()
  out$uis_version <- version
  out$downloaded <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  readr::write_csv(out, path)
  invisible(out)
}
