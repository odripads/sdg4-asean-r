# sdg4-asean-r

An R pipeline that downloads SDG 4 education indicators for the 11 ASEAN member states from the [UIS public data API](https://api.uis.unesco.org/api/public/documentation/), checks the published series for quality problems, and produces a reproducible report.

**Report:** [docs/index.html](https://odripads.github.io/sdg4-asean-r/), built from UIS data release `20261110` (November 2026).

## What it does

1. **Fetch** (`R/fetch.R`). Calls the UIS API with retries and throttling, and records the UIS data version and download time with every snapshot.
2. **Check** (`R/checks.R`). Four automated checks on the published series:
   - bounded percentages within 0–100
   - out-of-school rate = 100 − total net enrolment rate
   - the both-sexes GER lies between the female and male values
   - year-on-year jumps above 10 points
3. **Report** (`report.Rmd`):
   - data availability by indicator and country
   - completion rates (SDG 4.1.2)
   - out-of-school rates (SDG 4.1.4)
   - public spending against the Education 2030 benchmarks
   - the quality flags, with what they mean for using the data

## Findings in the current release

- The published series are internally consistent: no range, identity or sex-bracket failures.
- 14 large year-on-year breaks need checking before the series are used for trends. Examples:
  - Indonesia's upper-secondary completion rate is 75.8% in 2021, 43.0% in 2022 and 73.4% in 2023.
  - Qualified primary teachers show several breaks, a pattern often linked to changes in national definitions.
- Completion data, which come from household surveys, are far sparser than enrolment data. Malaysia has none since 2015, and Myanmar's latest is from 2016.
- 6 of 11 countries meet neither public-spending benchmark (4% of GDP, or 15% of public expenditure).

## Run it

```bash
Rscript run.R             # offline, from the saved snapshot in data/
Rscript run.R --refresh   # fresh download from the UIS API
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Packages: httr2, dplyr, tidyr, readr, purrr, ggplot2, ggrepel, rmarkdown, testthat.

## Files

```
R/fetch.R                API client and snapshot
R/checks.R               quality checks, coverage and latest-value helpers
report.Rmd               the report
run.R                    pipeline entry point
data/uis_sdg4_asean.csv  snapshot (with UIS version and download time)
data/quality_flags.csv   check results
docs/index.html          rendered report (GitHub Pages)
tests/testthat/          unit tests for the checks
```

Values are taken as published by the UIS and are not re-estimated. Interpretations of flags are prompts for checking against UIS metadata, not conclusions.
