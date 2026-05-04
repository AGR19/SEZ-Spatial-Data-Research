# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Stanford IRISS predoctoral research assignment under Tishara Garg. The task is to construct a reproducible spatial dataset of **industrial zones** in the **Philippines**, merge it with spatial/economic data, compare zone vs non-zone locations, and explore causal extensions.

Country chosen: **Philippines**

### Research Questions (from project description)
1. How place-based industrial policy (government-promoted industrial zones/parks) shapes economic development
2. How these policies address market failures — coordination failures in firms' investment decisions, urban congestion, environmental externalities
3. How to combine multiple data sources (census, survey, infrastructure, land lease records, satellite imagery) with quasi-experimental methods
4. How variation in land pricing, infrastructure rollout, policy guarantees affects timing, location & coordination of firm entry & investment

## Anti-Plagiarism Warning

**DO NOT** copy, replicate, or closely mirror Tishara Garg's JMP in any output. Her paper (`Gold Standard_JMP_TG.pdf`) is studied for understanding research methodology only. All code, analysis framing, variable construction, and writing must be original. Specifically:
- Do not use her exact regression specifications or model notation
- Do not replicate her distance bin structure
- Do not copy her data construction pipeline
- Frame research questions independently
- The file `Claude_TG_Insight.txt` is an internal learning document, NOT content to paste into deliverables

## Assignment Deliverables
1. `memo.pdf` — max 2 pages, must disclose AI usage
2. `sources.csv` — source audit table (source_name, link, type, raw_download_available, variables_used, credibility, limitation, next_step)
3. `zones.csv` — zone names, coordinates, optionally sector/size
4. `analysis_units.csv` — zone indicator + characteristics per spatial unit (one row per spatial unit)
5. `analysis.R` — reproducible code (R is the primary language)

## Evaluation Criteria
- **Strong:** Clearly communicates constraints, proposes next steps, makes verifiable claims, doesn't hide limitations, code is explainable. Incomplete is fine if transparent.
- **Weak:** Unverifiable claims, hidden limitations, unexplainable code.

## Data Distinction: Industrial Zones (primary) vs SEZs (additional)

- **Primary focus:** Industrial estates, industrial parks, manufacturing economic zones, export processing zones (EPZs), agro-industrial zones — places where manufacturing/industrial activity physically occurs
- **Additional/supplementary:** Broader SEZ data (IT parks, tourism zones, freeports) is supplementary under "additional spatial or economic data," NOT the main zone dataset

## Spatial Analysis Specifications
- **Spatial unit of analysis:** Philippine municipalities (~1,488 units)
- **CRS:** WGS 84 (EPSG:4326) for storage; PRS 92 (EPSG:3123) for distance calculations
- **Admin boundaries:** `faeldon/philippines-json-maps` GitHub repo (GeoJSON, PSGC-based) or GADM (gadm.org)

## Verified Data Sources

| Dataset | Source | Format | Status |
|---------|--------|--------|--------|
| PEZA Manufacturing Zones (74) | peza.gov.ph/sites/default/files/1.xls | Excel (.xls) | WORKING — complete list with names, locations, area, developer, investments (Nov 2017) |
| PEZA Agro-Industrial Zones (22+6) | peza.gov.ph/sites/default/files/3.xls | Excel (.xls) | WORKING — includes locator enterprises and PEZA approval/registration dates |
| Ravago et al. (2021) firm survey | Mendeley Data DOI: 10.17632/88t45xbn59.2 | CSV + TXT dict | CC-BY 4.0 — 115 firms in 26 ecozones, locatorid encodes province-city-zone-firm |
| Zone list (Wikipedia) | en.wikipedia.org/wiki/List_of_economic_zones_in_the_Philippines | HTML tables | Supplementary — 22 agro-industrial + 11 freeports listed |
| Admin boundaries | github.com/faeldon/philippines-json-maps | GeoJSON | Verified accessible |
| Admin boundaries | gadm.org (PHL) | SHP/GPKG | Verified accessible |
| Roads, rivers, ports | download.geofabrik.de/asia/philippines.html | PBF/SHP (568MB-1.3GB) | Verified accessible |
| Population density | WorldPop (hub.worldpop.org) | GeoTIFF, 1km, 2000-2020 | CC-BY 4.0 |
| Night lights | VIIRS DNB (eogdata.mines.edu) | GeoTIFF, ~500m, 2012+ | CC-BY 4.0 |
| Built-up area / urban extent | GHSL (human-settlement.emergency.copernicus.eu) | GeoTIFF tiles | Open/free |
| Coastline, rivers | Natural Earth (naturalearthdata.com, 10m) | Shapefile | Public domain |
| Airports | OurAirports (ourairports.com/data/) | CSV | Public domain |
| Country-level indicators | World Bank | CSV/Excel | Free |

See `Difficulties_Claude.txt` for datasets that could NOT be accessed and workarounds.

## Locatorid Encoding (from Ravago et al. 2021 Mendeley dataset)

The `locatorid` is a 9-digit standardized identifier encoding spatial location:

```
Format: PP-CC-EE-FFF
  PP  = Province code (2 digits)
  CC  = City/Municipality code (2 digits)
  EE  = Economic Zone code within that city (2 digits)
  FFF = Firm number within that zone (3 digits)
```

Province codes found in the dataset:
| Code | Province     |
|------|-------------|
| 01   | Batangas     |
| 02   | Benguet      |
| 03   | Bulacan      |
| 04   | Cavite       |
| 05   | Cebu         |
| 06   | Laguna       |
| 07   | Metro Manila |
| 08   | Pampanga     |

This encoding links firms to specific municipalities and zones, enabling spatial joins without coordinates. The dataset covers 26 ecozones across 8 provinces (115 firms total). Use this to cross-validate zone-municipality assignments from the PEZA Excel files.

Source: `raw datasets/mendeley_ravago/Supplementary Appendix 1 DIB Energy Ravago et al 2021_Data.csv`
Dictionary: `raw datasets/mendeley_ravago/Supplementary Appendix 2 DIB Energy Ravago et al 2021_Dictionary.txt`

## Coding Style Rules

Derived from the Fireline_DataScience reference projects. See `Fireline_DataScience/Claude_Fireline_Learning.txt` for full details with code snippets.

### R (primary language)
- `library()` calls at top, grouped by purpose
- `set.seed(42)` for reproducibility
- snake_case for variables and functions
- Section headers: `# === SECTION NAME ===`
- tidyverse for data manipulation (`dplyr` pipes `%>%`)
- `ggplot2` with `theme_minimal()` for publication-ready plots
- `sf` package for spatial operations with explicit `st_crs()` / `st_transform()`
- `cat()` with structured output and interpretation thresholds (e.g., "CFI: 0.95 (> 0.95 = excellent)")
- Comments explain WHY, not just WHAT — include reasoning for judgment calls
- Print data dimensions after every major transformation
- Keep earlier model iterations visible — do not delete failed attempts

### Python/GIS (if needed for spatial processing)
- `pd.read_csv()` with explicit `dtype={}` dict
- snake_case variables, UPPERCASE constants
- Section markers: `# ── SECTION NAME ──────────`
- Export to parquet (compressed) and CSV
- GeoPandas for spatial joins with explicit CRS

### Research Pipeline Pattern
1. Data ingestion with source documentation and record counts
2. Cleaning with validation checks (uniqueness, reconciliation)
3. Transformation (spatial joins, distance calculations, feature engineering)
4. Analysis (descriptive stats, comparisons, models)
5. Visualization (publication-ready, color-coded, reference lines)
6. Export with multiple formats and documentation

## Repository Structure

```
SEZ-Spatial-Data-Research/
├── CLAUDE.md                          # This file
├── README.md                          # Repo title
├── LICENSE                            # MIT License
├── Gold Standard_JMP_TG.pdf           # Tishara Garg's JMP (INTERNAL REFERENCE ONLY)
├── Claude_TG_Insight.txt              # Deep analysis of TG paper (internal learning)
├── Difficulties_Claude.txt            # Dataset access difficulties documented
├── raw datasets/
│   ├── peza_zones_raw.xls             # PEZA manufacturing zones (74) — from peza.gov.ph/sites/default/files/1.xls
│   ├── peza_locators_raw.xls          # PEZA agro-industrial zones (22+6) with locators — from peza.gov.ph/sites/default/files/3.xls
│   └── mendeley_ravago/               # Ravago et al. (2021) firm survey dataset — CC-BY 4.0
│       ├── Supplementary Appendix 1 ... _Data.csv          # 115 firms, 1257 variables, locatorid encoded
│       ├── Supplementary Appendix 2 ... _Dictionary.txt    # Variable names, types, labels
│       ├── Supplementary Appendix 3 ... _FGD Questionnaire.pdf
│       ├── Supplementary Appendix 4 ... _Survey Questionnaire.pdf
│       └── Supplementary Appendix 5 ... General results.pdf
├── Assignment Instructions/
│   ├── Written Assignment.pdf         # Official assignment instructions
│   └── My Insights and Questions/     # Handwritten notes, screenshots
├── Fireline_DataScience/              # Reference coding projects (DO NOT MODIFY)
│   ├── Claude_Fireline_Learning.txt   # Coding style learnings synthesized
│   ├── Learning flow simulator/       # Shiny for Python dashboard (app.py)
│   ├── ARC-GIS-datascience-main/      # GIS school data analysis (Jupyter notebooks)
│   └── koch_research-consolidate/     # R + Python stats (SEM, clustering, survival)
└── [assignment deliverables will go here]
    ├── sources.csv
    ├── zones.csv
    ├── analysis_units.csv
    ├── analysis.R
    └── memo.pdf
```

## Fireline Reference Projects

These are NOT part of the assignment — they are reference implementations for coding style:

- **Learning flow simulator** — Shiny for Python app pattern: data contracts, section markers, constant definitions, chart helpers
- **ARC-GIS-datascience-main** — GIS pipeline pattern: explicit dtypes, multi-table joins, spatial operations, multi-format export
- **koch_research-consolidate** — R statistical analysis pattern: lavaan SEM, ggplot2 visualization, iterative model refinement, structured console output with interpretation thresholds
