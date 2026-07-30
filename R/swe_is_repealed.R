#' Check whether a Swedish statute has been repealed
#'
#' A thin wrapper around [swe_get_doc()].
#'
#' @param sfs_nr Character. SFS number in the format "1974:152".
#' @return Logical. `TRUE` if repealed, `FALSE` otherwise.
#' @export
swe_is_repealed <- function(sfs_nr) {
  swe_get_doc(sfs_nr)$is_repealed
}