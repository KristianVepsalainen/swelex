test_that("swe_search() finds the constitution as top hit for 'regeringsform'", {
  skip_on_cran()
  skip_if_offline()
  
  result <- swe_search(query = "regeringsform", max_results = 5)
  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) > 0)
  expect_equal(result$sfs_nr[1], "1974:152")
})

test_that("swe_search() respects date range filters", {
  skip_on_cran()
  skip_if_offline()
  
  result <- swe_search(from_date = "2026-01-01", to_date = "2026-01-31")
  expect_true(all(result$datum >= as.Date("2026-01-01")))
  expect_true(all(result$datum <= as.Date("2026-01-31")))
})

test_that("swe_search() respects department filter", {
  skip_on_cran()
  skip_if_offline()
  
  result <- swe_search(org = "Justitiedepartementet", max_results = 5)
  expect_true(all(result$departement == "Justitiedepartementet"))
})

test_that("swe_search() returns an empty tibble (not an error) for no matches", {
  skip_on_cran()
  skip_if_offline()
  
  result <- swe_search(query = "xyzzyplugh123nonexistent")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("swe_search() excludes archival non-sfst documents", {
  skip_on_cran()
  skip_if_offline()
  
  result <- swe_search(query = "regeringsform", max_results = 10)
  expect_true(all(nchar(result$sfs_nr) > 0))
  expect_equal(nrow(result), 10)
})