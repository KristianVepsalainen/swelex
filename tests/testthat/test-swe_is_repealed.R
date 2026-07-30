# tests/testthat/test-swe_is_repealed.R
test_that("swe_is_repealed() correctly identifies repealed and active statutes", {
  skip_on_cran()
  skip_if_offline()
  
  expect_false(swe_is_repealed("1974:152"))
  expect_true(swe_is_repealed("1975:1385"))
})