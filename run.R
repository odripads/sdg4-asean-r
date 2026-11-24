# Rscript run.R            use the saved snapshot in data/ (offline, reproducible)
# Rscript run.R --refresh  download a fresh snapshot from the UIS API first

suppressPackageStartupMessages({
  library(dplyr)
})
source("R/fetch.R")
source("R/checks.R")

ASEAN <- c(BRN = "Brunei Darussalam", KHM = "Cambodia", IDN = "Indonesia", LAO = "Lao PDR",
           MYS = "Malaysia", MMR = "Myanmar", PHL = "Philippines", SGP = "Singapore",
           THA = "Thailand", TLS = "Timor-Leste", VNM = "Viet Nam")
INDICATORS <- c(
  "CR.1", "CR.2", "CR.3",                 # completion rates (SDG 4.1.2)
  "ROFST.1.CP", "ROFST.2.CP",             # out-of-school rates (SDG 4.1.4)
  "NERT.1.CP", "GER.1", "GER.1.F", "GER.1.M",
  "CR.1.GPIA",                            # adjusted gender parity, primary completion (SDG 4.5.1)
  "TRTP.1", "PTRHC.1",                    # teachers (SDG 4.c)
  "XGDP.FSGOV", "XGOVEXP.IMF"             # public expenditure (Education 2030 benchmarks)
)
START <- 2010
SNAPSHOT <- "data/uis_sdg4_asean.csv"

if ("--refresh" %in% commandArgs(trailingOnly = TRUE) || !file.exists(SNAPSHOT)) {
  message("Downloading from the UIS API...")
  uis_snapshot(INDICATORS, names(ASEAN), START, SNAPSHOT)
}
df <- readr::read_csv(SNAPSHOT, show_col_types = FALSE)
message(sprintf("%s rows, UIS data version %s", format(nrow(df), big.mark = ","), df$uis_version[1]))

flags <- run_checks(df) |> arrange(check, iso3, indicator, year)
readr::write_csv(flags, "data/quality_flags.csv")
message(sprintf("%d quality flags written to data/quality_flags.csv", nrow(flags)))

rmarkdown::render("report.Rmd", output_file = "index.html", output_dir = "docs", quiet = TRUE,
                  params = list(snapshot = SNAPSHOT))
message("Report: docs/index.html")
