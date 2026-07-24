#' Get a Swedish statute (SFS) document
#'
#' Retrieves the consolidated, up-to-date text and metadata of a Swedish
#' statute from Riksdagen's open data API.
#'
#' @param sfs_nr Character. SFS number in the format "1974:152".
#' @return A one-row tibble with columns: `sfs_nr`, `titel`, `departement`,
#'   `utfardad`, `andrad_tom`, `upphavd`, `upphavd_av`, `is_repealed`, `text`.
#' @export
swe_get_doc <- function(sfs_nr) {
  dok_id <- sfs_nr_to_dok_id(sfs_nr)
  
  resp <- tryCatch(
    httr2::request("https://data.riksdagen.se") |>
      httr2::req_url_path_append("dokumentstatus", paste0(dok_id, ".json")) |>
      httr2::req_user_agent("swelex R package (https://github.com/KristianVepsalainen/swelex)") |>
      httr2::req_retry(max_tries = 3, backoff = ~ 2) |>
      httr2::req_perform(),
    
    httr2_http_404 = function(cnd) {
      cli::cli_abort(
        "SFS {sfs_nr} was not found in Riksdagen's open data (HTTP 404).",
        class = "swelex_not_found"
      )
    },
    httr2_http = function(cnd) {
      cli::cli_abort(
        c(
          "Riksdagen's API returned an error for SFS {sfs_nr}.",
          "i" = "Check {.url https://storning.riksdagen.se/} for service disruptions."
        ),
        class = "swelex_api_error",
        parent = cnd
      )
    },
    httr2_failure = function(cnd) {
      cli::cli_abort(
        c(
          "Could not reach Riksdagen's API for SFS {sfs_nr}.",
          "i" = "The service may be down. Check {.url https://storning.riksdagen.se/}."
        ),
        class = "swelex_connection_error",
        parent = cnd
      )
    }
  )
  
  parsed <- httr2::resp_body_json(resp)
  doc <- parsed$dokumentstatus$dokument
  uppgifter <- parse_dokumentuppgift(parsed$dokumentstatus$dokumentuppgift$uppgift)
  
  upphavd_datum <- if (!is.null(uppgifter$upphavd)) {
    as.Date(uppgifter$upphavd)
  } else {
    as.Date(NA)
  }
  upphavd_av <- if (!is.null(uppgifter$upphnr)) uppgifter$upphnr else NA_character_
  
  tibble::tibble(
    sfs_nr      = doc$beteckning,
    titel       = doc$titel,
    departement = doc$organ,
    utfardad    = as.Date(doc$datum),
    andrad_tom  = doc$subtitel,
    upphavd     = upphavd_datum,
    upphavd_av  = upphavd_av,
    is_repealed = !is.na(upphavd_datum),
    text        = doc$text
  )
}

#' Convert an SFS number to Riksdagen's document id
#'
#' @param sfs_nr Character. SFS number in the format "1974:152".
#' @return Character. Document id in the format "sfs-1974-152".
#' @noRd
sfs_nr_to_dok_id <- function(sfs_nr) {
  if (!grepl("^\\d{4}:\\d+$", sfs_nr)) {
    cli::cli_abort(
      "{.arg sfs_nr} must be in the format 'YYYY:NNN', e.g. '1974:152'.",
      class = "swelex_invalid_input"
    )
  }
  paste0("sfs-", sub(":", "-", sfs_nr))
}

#' Parse a dokumentuppgift$uppgift list into a named list (kod -> text)
#'
#' @param uppgift_list A list of `list(kod, namn, text)` entries as returned
#'   by Riksdagen's `dokumentstatus` endpoint.
#' @return A named list, e.g. `list(upphavd = "2006-01-01 00:00:00")`.
#' @noRd
parse_dokumentuppgift <- function(uppgift_list) {
  if (length(uppgift_list) == 0) {
    return(list())
  }
  kod  <- vapply(uppgift_list, function(x) x$kod, character(1))
  text <- vapply(uppgift_list, function(x) x$text, character(1))
  stats::setNames(as.list(text), kod)
}