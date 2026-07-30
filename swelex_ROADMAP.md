# swelex — Roadmap to CRAN

**Package:** `swelex` — R wrapper for the Swedish Code of Statutes (Svensk
författningssamling, SFS) via the Riksdag's open data API.

**Strategic context:** unlike `finlex`, this is a *new* lexverse package.
Per the portfolio-rotation lesson learned from the finlex 0.1.0 → 0.2.0 CRAN
episode (Uwe Ligges flagged an update one day after the previous one), the
bar for a *first* CRAN submission on a new package is higher than it was for
finlex: we build broad, "product-level" function coverage before submitting,
because the next realistic update window is ~6 months out. **No thin MVP.**

---

## 1. API landscape (confirmed facts)

- **Base:** `https://data.riksdagen.se` — free, no API key, JSON/XML/CSV.
- **No Swagger/OpenAPI spec exists.** Documentation is prose-only at
  `riksdagen.se/sv/dokument-och-lagar/riksdagens-oppna-data/`. All field
  semantics must be reverse-engineered empirically (as we are doing).
- **No published rate-limit policy found.** Treat as unknown — implement
  conservative retry/backoff regardless (`httr2::req_retry()`,
  `req_throttle()`), same "polite" posture as finlex.
- **Reliability risk confirmed live:** Riksdagen's own status page
  (`storning.riksdagen.se`) shows the service has real, unannounced outages
  (observed directly 2026-07-24; historical outages reported by SVT in 2025
  and 2026). Package must degrade gracefully, not just handle 404s.

### Two relevant endpoints

| Endpoint | Purpose | Format |
|---|---|---|
| `/dokumentlista/?doktyp=sfs&...` | search/list (filters: `sok`, `rm`, `nr`, `from`/`tom`, pagination via `sz`/`p`) | JSON/XML/CSV |
| `/dokumentstatus/{dok_id}.json` | single document, full consolidated text + metadata | JSON |

- `dok_id` pattern confirmed: `sfs-{rm}-{nummer}`, e.g. SFS 1974:152 →
  `sfs-1974-152`. Deterministic — no lookup needed to build the URL from an
  SFS number.
- `subtyp: "sfst"` on every observed document — working hypothesis is that
  `dokumentstatus` returns the **consolidated, up-to-date text** (mirroring
  Regeringskansliet's SFST database), not the as-enacted original. Confirmed
  for SFS 1974:152 (Regeringsformen): `subtitel` field reads
  `"t.o.m. SFS 2022:1600"` and amendment markers (`Lag (2010:1408).`) appear
  inline in the text — same consolidation pattern as Finlex. **This is the
  single most important architectural finding**: no in-house consolidation
  logic needed, unlike a from-scratch scrape-based approach would require.

### Open / unresolved questions

- [x] ~~Repealed statutes~~ **Resolved 2026-07-24**: `dokumentuppgift$uppgift`
  contains `kod: "upphavd"` (repeal date) and `kod: "upphnr"` (repealing SFS
  number) when a statute has been repealed; both are absent for statutes
  still in force. `$dokument$status` is always empty — not a useful signal.
- [x] ~~Does `dokumentlista` free-text search~~ **Resolved 2026-07-26**: yes,
  `sok=` works as free text, but **default sort order is not
  relevance-based** — a query like "regeringsform" returned unrelated
  results (e.g. gas-price subsidy regulations) sorted purely by date. Adding
  `sort=rel&sortorder=desc` fixes this; confirmed via the `score` field
  (e.g. 1974:152 scored 36451 vs. ~1000-3000 for the next most relevant
  results). `swe_search()` now applies this sort by default — not optional,
  since without it the function is close to useless for its main purpose.
- [x] ~~**Edge case found 2026-07-26**: one result for query "regeringsform"
  had an empty `sfs_nr`~~ **Resolved 2026-07-30**: traced to `subtyp:
  "regl-riksb"` — an 1898 Riksbank charter (`Reglemente för Riksbankens
  styrelse och förvaltning`) from a KB (Kungliga biblioteket) OCR
  digitisation project (`kalla: "digitalisering"`, `status: "ocr"`).
  General pattern: `doktyp=sfs` includes archival/non-consolidated
  documents alongside modern `sfst` statutes. Fix: `swe_search()` now
  filters to `subtyp == "sfst"` only. **Second bug found while fixing
  this**: the pagination stop condition originally compared filtered
  result count against page size, causing `max_results=10` to silently
  return only 9 rows whenever a page contained an archival document.
  Fixed by comparing the raw (pre-filter) page length instead. Both fixes
  verified: 10/10 rows returned, all with non-empty `sfs_nr`.
- [ ] **Possible future optimisation**: `swe_get_metadata()` currently makes
  the same full `dokumentstatus` call as `swe_get_doc()` and just drops
  `text` — no real bandwidth saving. A genuinely lighter metadata-only path
  might exist via `dokumentlista` with `nr=`+`rm=` params (untested; `bet=`
  was confirmed not to work for `doktyp=sfs`, but `nr`+`rm` together were
  never tried). Worth investigating if bulk metadata harvesting becomes a
  real use case (e.g. for a future `lexnet` citation network).
- [ ] Does `dokumentlista` free-text search (`sok=`) reliably find a statute
  by SFS number, or only by title keywords? (`bet=` parameter confirmed
  **not** to work for `doktyp=sfs`.)
- [ ] Pagination behaviour at scale — `@sidor: 3847` pages for the full SFS
  corpus at `sz=3`; need to confirm sane `sz` upper bound and whether bulk
  retrieval is anywhere near practical/allowed.
- [x] ~~Does the API expose amendment history as structured data~~
  **Resolved 2026-07-30, answer: no.** `dokumentuppgift$uppgift` for a
  heavily-amended statute (SFS 1974:152, 50+ years of amendments) exposes
  only six fields (`artal`, `utfardad`, `text2`, `andrattillochmed`,
  `omtryck`, `utdrag`) — no list of individual amending SFS numbers, only
  the flattened "t.o.m. SFS X" string naming the *most recent* amendment.
  Free-text search for the SFS number itself (`sok="1974:152"`) returned
  only the statute's own document, not any of the amending acts. **No
  structured amendment history is retrievable via this API without
  scraping** `rkrattsbaser.gov.se`'s change register (SFSR) — which is out
  of scope per the no-scraping decision. `swe_list_changes()` is therefore
  **deferred indefinitely**, not just unscoped for v1.0 — move to Section
  2 status accordingly.
- [ ] Confirm actual behaviour on repeated rapid requests (possible informal
  rate limiting) once service is back up.

---

## 1b. Naming/language decisions

- **Column names stay in source-language (Swedish) form**: `titel`,
  `departement`, `utfardad`, `andrad_tom`, `upphavd`, `upphavd_av` — not
  translated to English. Decided 2026-07-24, mirrors the finlex precedent of
  keeping source-language field names in the returned tibbles.
- **Deferred:** an English-column-name wrapper/alias layer (e.g.
  `swe_get_doc_en()` or a `janitor`-style rename helper) is explicitly
  planned for *later*, not v1.0. Add to Section 2 once scoped.
- Roxygen documentation, exported error messages, and all in-code comments
  are English throughout (CRAN-facing) — confirmed and corrected 2026-07-24
  after an early draft mixed Swedish/Finnish into user-facing text.

## 2. Function inventory (target: "near-complete" v1.0, not MVP)

Naming convention: `swe_` prefix (broader than `sfs_`, since Riksdagen's API
also covers propositions/betänkanden etc. that could matter for lexverse
later — mirrors `flx_` in finlex).

| Function | Status | Purpose |
|---|---|---|
| `swe_get_doc(sfs_nr)` | 🟢 done (v1) | Single document, full metadata + consolidated text. 404, generic-HTTP-error and connection-failure handling implemented and passing in `testthat` with `httptest2` mocks (11/11 tests). Repealed-statute detection (`upphavd`, `upphavd_av`, `is_repealed`) implemented via `dokumentuppgift$uppgift` parsing. |
| `swe_search(...)` | 🟢 done (v1) | Wraps `dokumentlista`: free text, date range (`from_date`/`to_date`), department (`org`), session year (`rm`), pagination. Defaults to `sort=rel&sortorder=desc` — confirmed empirically necessary. Filters out non-`sfst` archival documents. Returns empty tibble (not an error) on no matches. 5/5 tests passing. |
| `swe_get_text(sfs_nr)` | 🟢 done (v1) | Thin wrapper returning only the text string. 3/3 tests passing. |
| `swe_get_metadata(sfs_nr)` | 🟢 done (v1) | Thin wrapper returning metadata tibble minus `text`. **Not actually cheaper** — same `dokumentstatus` call under the hood; a real bandwidth-saving version would need a different route (see optimisation note below). 3/3 tests passing. |
| `swe_list_changes(sfs_nr)` | ⛔ deferred indefinitely | **Not feasible without scraping** — confirmed 2026-07-30 that Riksdagen's API exposes no structured amendment history, only a flattened "most recent amendment" string. Would require scraping `rkrattsbaser.gov.se`'s SFSR register, which is explicitly out of scope per the no-scraping decision. Revisit only if that decision changes. |
| `swe_is_repealed(sfs_nr)` | 🟢 trivial, ready to add | No longer blocked — `is_repealed` is already computed in `swe_get_doc()`. A one-line convenience wrapper (`swe_get_doc(sfs_nr)$is_repealed`), same pattern as `swe_get_text()`. |
| `sfs_nr_to_dok_id()` / `dok_id_to_sfs_nr()` | 🟢 first one done | Internal helpers, likely exported since users may want to construct URLs themselves. |

*(This table is intentionally the living center of the roadmap — update
status here as we go rather than in a separate task list.)*

---

## 3. Engineering checklist (mirrors finlex/eurlex CRAN patterns)

- [x] `httr2` throughout, own polite `User-Agent`, `req_retry()` — done in
  `swe_get_doc()`
- [x] Graceful handling of: 404, other HTTP errors (`httr2_http`), and
  transport-level failures (`httr2_failure`, e.g. the connection-reset
  outage observed 2026-07-24) — all three raise structured `swelex_*`
  condition classes with a pointer to `storning.riksdagen.se`. 404 path
  verified live and via mock; `httr2_http`/`httr2_failure` paths are
  written defensively but still untested against a real 5xx/outage
  response (low priority — revisit opportunistically if Riksdagen has
  another outage).
- [x] `testthat` (edition 3), `skip_on_cran()` + `skip_if_offline()` pattern
  — **not** httptest2. Course-corrected 2026-07-24: initially built
  httptest2 mocks, but hit two friction points (fixture path length >100
  bytes breaking the CRAN tarball check; a botched `git mv` silently
  leaving stale fixture dirs) that outweighed the benefit for this simple
  a package. Switched to the same live-request-but-skippable pattern
  finlex already uses — simpler, consistent across lexverse, and CRAN
  machines skip these tests entirely via `skip_on_cran()` regardless.
  `test-swe_get_doc.R`: 4 test blocks covering success / 404 /
  repealed-statute / input-validation.
  - **`httr2_failure` path confirmed live**, not just written defensively:
    a genuine Riksdagen outage (`storning.riksdagen.se` showing "Vi
    arbetar för att lösa problemet", observed twice on 2026-07-24) caused
    real `Recv failure: Connection reset by peer` errors, and
    `swe_get_doc()` correctly surfaced the structured
    `swelex_connection_error` with a pointer to the status page. Note:
    `skip_if_offline()` only checks general connectivity, not the target
    service, so it does not skip when only Riksdagen itself is down —
    tests correctly attempt and correctly fail in that case.
  - `httr2_http` (generic non-404 HTTP error) path still not exercised
    live — low priority, revisit opportunistically.
- [ ] `skip_on_cran()` + `skip_if_offline()` on all network tests
- [ ] Pre-computed vignette (`.Rmd.orig` → `.Rmd`), no live API calls at
  CRAN check time
- [ ] `devtools::check(cran = TRUE)`, win-builder, R-hub v2
  (Linux/Windows/macOS arm64)
- [ ] `cli`-based error/condition classes (`swelex_not_found`, etc.) for
  testable, structured errors
- [x] Pin `Depends: R (>= 4.1.0)` explicitly in DESCRIPTION rather than
  relying on automatic inference from `|>` usage (CRAN check surfaced this
  as an automatic-detection WARNING on first CI run — better to state it)
- [x] `usethis::use_build_ignore("swelex_ROADMAP.md")` — CRAN check flags
  non-standard top-level files; roadmap stays in git, excluded from the
  build tarball
- [x] First CI run went green 2026-07-24 (after two rounds of fixes: R
  dependency pin, ROADMAP build-ignore, and the httptest2 → skip_on_cran/
  skip_if_offline switch). One transient, unrelated CI infra failure
  encountered along the way (`setup-r-dependencies`'s `pak` install failed
  on the Windows runner with "there is no package called 'pak'") — this is
  a known intermittent issue in `r-lib/actions`, not a swelex problem;
  resolved by simply re-running the failed job.
- [ ] README + pkgdown site
- [ ] Swedish diacritics correctness pass before release (å/ä/ö) — same
  discipline as the Finnish diacritics rule for finlex

---

## 4. Sequencing

1. ~~API reconnaissance~~ ✅
2. ~~`swe_get_doc()` + package skeleton~~ ✅ committed, CI green
3. ~~`swe_search()`~~ ✅ implemented, hardened, 21/21 tests, CI green
4. ~~Thin wrappers (`swe_get_text`, `swe_get_metadata`)~~ ✅ 27/27 tests,
   `devtools::check()`: 0/0/0
5. ~~Amendment-history question~~ ✅ resolved: not feasible without
   scraping, `swe_list_changes()` deferred indefinitely
6. **Next up:** add trivial `swe_is_repealed()` wrapper, then move to
   pre-computed vignette
7. CRAN pre-flight checklist (Section 3) end to end
8. Submit — **once**, aiming for the ~6-month cadence, product-complete

---

*Last updated: 2026-07-30. Amendment-history question resolved (not
feasible without scraping — swe_list_changes() deferred indefinitely).
Function inventory for v1.0 is now essentially settled: swe_get_doc,
swe_search, swe_get_text, swe_get_metadata done; swe_is_repealed trivial
to add. Next: add that wrapper, then move to the pre-computed vignette
and CRAN pre-flight checklist. Update this file as decisions are made —
don't let a separate task list drift out of sync with it.*
