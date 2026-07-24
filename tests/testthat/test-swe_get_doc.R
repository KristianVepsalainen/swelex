library(httptest2)

test_that("swe_get_doc() returns expected tibble for a known statute", {
  with_mock_dir("fixtures/swe_get_doc_success", {
    result <- swe_get_doc("1974:152")
    expect_s3_class(result, "tbl_df")
    expect_equal(result$sfs_nr, "1974:152")
    expect_true(grepl("regeringsform", tolower(result$titel)))
    expect_false(result$is_repealed)
    expect_true(is.na(result$upphavd))
  })
})

test_that("swe_get_doc() errors informatively for unknown SFS number", {
  with_mock_dir("fixtures/swe_get_doc_404", {
    expect_error(swe_get_doc("9999:999"), class = "swelex_not_found")
  })
})

test_that("swe_get_doc() correctly identifies a repealed statute", {
  with_mock_dir("fixtures/swe_get_doc_repealed", {
    result <- swe_get_doc("1975:1385")
    expect_true(result$is_repealed)
    expect_equal(result$upphavd, as.Date("2006-01-01"))
    expect_equal(result$upphavd_av, "SFS 2005:552")
  })
})

test_that("sfs_nr_to_dok_id() validates format", {
  expect_error(sfs_nr_to_dok_id("bad-format"), class = "swelex_invalid_input")
  expect_equal(sfs_nr_to_dok_id("1974:152"), "sfs-1974-152")
})