## R CMD check results

0 errors | 0 warnings | 0 notes (local)

## Test environments

* local: Fedora Linux, R 4.6.1
* GitHub Actions (r-lib/actions check-standard):
  ubuntu-latest (release, devel, oldrel-1), windows-latest, macOS-latest
* win-builder (R-devel): 1 NOTE (see below)

## R CMD check results on win-builder

1 NOTE:

* "New submission" — expected, this is a first submission.
* Words flagged as possibly misspelled (Riksdag's, Riksdagen's, SFS,
  Svensk, lexverse, författningssamling) are proper nouns, an acronym,
  and the name of a Swedish-legislation API and its publisher — not
  spelling errors.

## Notes for CRAN reviewers

This is a new submission.

swelex provides access to the Swedish Code of Statutes 
(Svensk författningssamling, SFS) via the Riksdag's (Sweden's parliament) 
open data API.

Network-dependent tests use skip_on_cran() and skip_if_offline(). The
vignette is pre-computed (vignettes/*.Rmd.orig -> *.Rmd) so R CMD check
performs no live network calls.