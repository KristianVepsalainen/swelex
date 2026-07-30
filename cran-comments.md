## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local: Fedora Linux, R 4.6.1
* GitHub Actions: ubuntu-latest (release, devel, oldrel-1), windows-latest, macOS-latest

## Notes for CRAN reviewers

This is a new submission.

Network-dependent tests use skip_on_cran() and skip_if_offline(), since
they depend on the live availability of Riksdagen's (Sweden's parliament)
open data API. The vignette is pre-computed (no live API calls during
R CMD check).