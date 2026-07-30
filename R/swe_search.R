#' Search Swedish statutes (SFS)
#'
#' Searches Riksdagen's open data for statutes matching free text, a date
#' range, an issuing department, or a session year, sorted by relevance.
#' Unlike `swe_get_doc()`, an empty result set is not an error — it simply
#' means no statutes matched.
#'
#' @param query Character. Free-text search term, matched against title and
#'   body text. Optional.
#' @param from_date,to_date Character or Date, format "YYYY-MM-DD".
#'   Restrict to statutes issued within this range. Optional.
#' @param org Character. Filter by issuing department/authority, e.g.
#'   "Justitiedepartementet". Optional.
#' @param rm Character. Filter by Riksdag session year, e.g. "2022".
#'   Optional.
#' @param max_results Integer. Maximum number of results to return.
#'   Default 50.
#' @return A tibble with columns: sfs_nr, titel, departement, datum,
#'   dok_id, summary, score. Zero rows if nothing matched. Sorted by
#'   relevance (descending) when `query` is supplied.
#' @export
swe_search <- function(query = NULL, from_date = NULL, to_date = NULL,
                       org = NULL, rm = NULL, max_results = 50) {
  page_size <- min(max_results, 100)
  results <- list()
  page <- 1
  
  repeat {
    req <- httr2::request("https://data.riksdagen.se/dokumentlista/") |>
      httr2::req_url_query(
        doktyp    = "sfs",
        sok       = query,
        from      = from_date,
        tom       = to_date,
        org       = org,
        rm        = rm,
        sort      = "rel",
        sortorder = "desc",
        sz        = page_size,
        p         = page,
        utformat  = "json"
      ) |>
      httr2::req_user_agent("swelex R package (https://github.com/KristianVepsalainen/swelex)") |>
      httr2::req_retry(max_tries = 3, backoff = ~ 2)
    
    resp <- perform_riksdagen_request(req, "SFS search")
    parsed <- httr2::resp_body_json(resp)
    dokument_raw <- parsed$dokumentlista$dokument
    
    if (length(dokument_raw) == 0) break
    
    # Exclude archival/OCR-scanned documents (subtyp != "sfst") — these
    # lack beteckning, consolidated text, and the dokumentstatus structure
    # the rest of swelex relies on. See ROADMAP.md for the "Riksbankens
    # styrelse" 1898 case that surfaced this.
    is_modern_sfst <- vapply(dokument_raw, function(x) identical(x$subtyp, "sfst"), logical(1))
    dokument <- dokument_raw[is_modern_sfst]
    
    results <- c(results, dokument)
    
    if (length(results) >= max_results) break
    if (length(dokument_raw) < page_size) break  # raw page was short -> API's last page
    page <- page + 1
  }
  
  results <- utils::head(results, max_results)
  
  if (length(results) == 0) {
    return(tibble::tibble(
      sfs_nr = character(), titel = character(), departement = character(),
      datum = as.Date(character()), dok_id = character(),
      summary = character(), score = double()
    ))
  }
  
  tibble::tibble(
    sfs_nr      = vapply(results, function(x) x$beteckning, character(1)),
    titel       = vapply(results, function(x) x$titel, character(1)),
    departement = vapply(results, function(x) x$organ, character(1)),
    datum       = as.Date(vapply(results, function(x) x$datum, character(1))),
    dok_id      = vapply(results, function(x) x$dok_id, character(1)),
    summary     = vapply(results, function(x) x$summary, character(1)),
    score       = as.numeric(gsub(",", ".", vapply(results, function(x) x$score, character(1))))
  )
}