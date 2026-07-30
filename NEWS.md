# swelex 0.1.0

Initial CRAN submission.

* `swe_get_doc()`: fetch a single Swedish statute (SFS) by number, with
  consolidated up-to-date text, metadata, and repealed-statute detection
* `swe_search()`: relevance-ranked free-text search over SFS, with date
  range, department, and session-year filters
* `swe_get_text()`, `swe_get_metadata()`: thin wrappers around
  `swe_get_doc()` for text-only or metadata-only access
* `swe_is_repealed()`: convenience wrapper to check repeal status