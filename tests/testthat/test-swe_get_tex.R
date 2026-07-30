# tests/testthat/test-swe_get_text.R
test_that("swe_get_text() returns just the text", {
  skip_on_cran()
  skip_if_offline()
  
  txt <- swe_get_text("1974:152")
  expect_type(txt, "character")
  expect_length(txt, 1)
  expect_true(grepl("Statsskickets grunder", txt))
})

test_that("swe_get_metadata() drops the text column", {
  skip_on_cran()
  skip_if_offline()
  
  meta <- swe_get_metadata("1974:152")
  expect_s3_class(meta, "tbl_df")
  expect_false("text" %in% names(meta))
  expect_equal(meta$sfs_nr, "1974:152")
})