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
- [ ] Does `dokumentlista` free-text search (`sok=`) reliably find a statute
  by SFS number, or only by title keywords? (`bet=` parameter confirmed
  **not** to work for `doktyp=sfs`.)
- [ ] Pagination behaviour at scale — `@sidor: 3847` pages for the full SFS
  corpus at `sz=3`; need to confirm sane `sz` upper bound and whether bulk
  retrieval is anywhere near practical/allowed.
- [ ] Does the API expose amendment history as structured data (e.g. a
  changelog of every SFS number that touched a given statute), or only the
  flattened "t.o.m. SFS X" string? This matters a lot for any future
  `lexnet`-style citation network work.
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
| `swe_search(...)` | ⬜ not started | Wraps `dokumentlista`: free text, date range, `rm`, department/`organ` filter, pagination. |
| `swe_get_text(sfs_nr)` | ⬜ not started | Thin wrapper returning only the text string (mirrors `flx_get_text()`). |
| `swe_get_metadata(sfs_nr)` | ⬜ not started | Thin wrapper returning only metadata tibble, no full text (cheaper calls for bulk metadata work). |
| `swe_list_changes(sfs_nr)` | ⬜ needs API research | Amendment history for a statute, if the API exposes it structurally (see open question above). |
| `swe_is_repealed(sfs_nr)` | ⬜ blocked | Depends on resolving the repealed-statute field question. |
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

1. ~~API reconnaissance~~ ✅ (this document captures the findings)
2. ~~Finish `swe_get_doc()` incl. repealed-statute + outage handling~~ ✅
   package skeleton created (`usethis::create_package()`, MIT license,
   roxygen-md, testthat 3, GH Actions check-standard), `swe_get_doc()` +
   helpers implemented in `R/swe_get_doc.R`, 11/11 tests passing with
   httptest2 mocks
3. **Next up:** design + build `swe_search()` (needed for almost everything
   else — discovery of SFS numbers by topic/date)
4. Build remaining thin wrappers (`swe_get_text`, `swe_get_metadata`)
5. Resolve amendment-history question → decide whether `swe_list_changes()`
   is in scope for v1.0 or deferred
6. Pre-computed vignette
7. CRAN pre-flight checklist (Section 3) end to end
8. Submit — **once**, aiming for the ~6-month cadence, product-complete

---

*Last updated: 2026-07-24. First CI run green: package skeleton +
swe_get_doc() fully committed, pushed, and verified on a clean external
runner. Milestone reached — ready to move to swe_search(). Update this
file as decisions are made — don't let a separate task list drift out of
sync with it.*
