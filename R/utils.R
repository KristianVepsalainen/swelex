#' Perform a request against Riksdagen's API with swelex error handling
#'
#' @param req An `httr2_request` object.
#' @param context Character. Human-readable description of what was being
#'   fetched, used in error messages (e.g. "SFS 1974:152").
#' @return An `httr2_response` object.
#' @noRd
perform_riksdagen_request <- function(req, context) {
  tryCatch(
    httr2::req_perform(req),
    httr2_http_404 = function(cnd) {
      cli::cli_abort(
        "{context} was not found in Riksdagen's open data (HTTP 404).",
        class = "swelex_not_found"
      )
    },
    httr2_http = function(cnd) {
      cli::cli_abort(
        c(
          "Riksdagen's API returned an error for {context}.",
          "i" = "Check {.url https://storning.riksdagen.se/} for service disruptions."
        ),
        class = "swelex_api_error",
        parent = cnd
      )
    },
    httr2_failure = function(cnd) {
      cli::cli_abort(
        c(
          "Could not reach Riksdagen's API for {context}.",
          "i" = "The service may be down. Check {.url https://storning.riksdagen.se/}."
        ),
        class = "swelex_connection_error",
        parent = cnd
      )
    }
  )
}