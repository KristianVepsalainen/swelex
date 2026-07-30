#' Get the consolidated text of a Swedish statute
#'
#' A thin wrapper around [swe_get_doc()] that returns only the text.
#'
#' @param sfs_nr Character. SFS number in the format "1974:152".
#' @return Character. The consolidated statute text.
#' @export
swe_get_text <- function(sfs_nr) {
  swe_get_doc(sfs_nr)$text
}

#' Get metadata for a Swedish statute, without the full text
#'
#' A thin wrapper around [swe_get_doc()] that drops the `text` column.
#' Note: this still performs the same API call as `swe_get_doc()` — the
#' underlying endpoint does not support a text-free response — so it is a
#' convenience wrapper, not a lighter-weight one. See ROADMAP.md for a
#' possible future optimisation via the `dokumentlista` endpoint.
#'
#' @param sfs_nr Character. SFS number in the format "1974:152".
#' @return A one-row tibble with columns: `sfs_nr`, `titel`, `departement`,
#'   `utfardad`, `andrad_tom`, `upphavd`, `upphavd_av`, `is_repealed`.
#' @export
swe_get_metadata <- function(sfs_nr) {
  doc <- swe_get_doc(sfs_nr)
  doc[, setdiff(names(doc), "text")]
}