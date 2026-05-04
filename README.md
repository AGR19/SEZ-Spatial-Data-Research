# Philippines Industrial Zones: Spatial Data Research

**Live Dashboard:** [https://agr19.shinyapps.io/philippines-industrial-zones/](https://agr19.shinyapps.io/philippines-industrial-zones/)

- ArcGIS maps available in the repo: [Result Maps ArcGIS](https://github.com/AGR19/SEZ-Spatial-Data-Research/tree/main/Result%20Maps%20ArcGIS)
- R-generated figures available here: [figures/](https://github.com/AGR19/SEZ-Spatial-Data-Research/tree/main/figures)

## Research Question

Where are industrial zones located in the Philippines, and how do zone locations differ from non-zone locations in terms of population density, nighttime economic activity, infrastructure proximity, and land cover?

**Country:** Philippines
**Spatial unit of analysis:** Municipality (~1,628 units, GADM level 2)
**Coordinate Reference System:** EPSG:4326 (WGS 84) for storage; EPSG:3123 (PRS 92) for distance calculations
**Primary language:** R
**GIS tool:** ArcGIS Pro (with Living Atlas via Arizona State University account)
**Admin boundaries:** GADM v4.1 Philippines (shapefiles for ArcGIS Pro, geopackage for R)

## Assignment Part Mapping

| Assignment Part | Deliverable | analysis.R Sections |
|---|---|---|
| **Part 1:** Find and construct zone data | `zones.csv` (102 zones) | Sections 1.1–1.8 |
| **Part 2:** Merge additional spatial/economic data | `analysis_units.csv` (1,628 municipalities) | Sections 2.1–2.8 |
| **Part 3:** Compare zone and non-zone locations | Summary stats, logistic regression, 6 figures | Sections 3.1–3.5 |
| **Part 4:** Dynamic and causal extension | Establishment timeline, proposed DiD design | Sections 4.1–4.3 |

## Data Sources (19 total)

See `sources.csv` for the complete source audit table with links, types, variables, credibility, limitations, and next steps.

### Zone Data (Primary — Industrial Zones)

| Source | Zones | Has Coordinates | Has Est. Year | Zone Types |
|---|---|---|---|---|
| PEZA Manufacturing (1.xls) | 74 | No → geocoded to municipality centroids | No | Manufacturing |
| PEZA Agro-Industrial (3.xls) | 22 + 6 proclaimed | No → geocoded to municipality centroids | PEZA approval dates | Agro-industrial |
| World Bank CIIP SEZ Database | 47 | Yes (lat/lon) | Yes (1974–2014) | ECOzone |
| Wikipedia Economic Zones List | 30 | No → geocoded to municipality centroids | No | Agro-industrial, Freeport |
| Ravago et al. (2021) Mendeley | 26 ecozones (115 firms) | Locatorid encoding | No | Manufacturing, Agro-industrial |

**Note on zone type coverage:** This dataset focuses on **industrial zones** (manufacturing, agro-industrial, export processing, freeports). IT Parks (262), Tourism Zones (19), and Medical Tourism Parks (2) exist in the Philippines but are not individually listed in available public data and are outside the primary industrial focus of this assignment. This limitation is documented transparently.

### Spatial and Economic Data

| Dataset | Resolution | Time Period | Used For |
|---|---|---|---|
| GADM Philippines v4.1 | Municipality polygons | Current | Admin boundaries (R + ArcGIS Pro) |
| WorldPop Population Density | ~1 km | 2020 | Population density per municipality |
| VIIRS Nighttime Lights | ~500 m | 2018 | Economic activity proxy |
| GHSL Built-up Surface | ~1 km | 2020 | Urbanization measure (normalized 0–1) |
| Hansen Global Forest Change | 30 m | 2000 baseline, loss 2001–2024 | Forest cover |
| JRC Global Surface Water | 30 m | 1984–2021 cumulative | Water body identification |
| OpenStreetMap Philippines | Vector shapefiles | 2026 snapshot | Roads, waterways, ports, transport |
| OurAirports | Point CSV | 2026 snapshot | Airport locations and distances |
| HDX 2015 Census Population | Barangay level | 2015 | Census population by municipality |
| WDPCA Protected Areas | Polygon | 1919–2021 | Protected area overlap |

### Economic Context (Country-level)

| Dataset | Indicators | Time Period |
|---|---|---|
| World Bank Development Indicators | 1,486 | 1960–2025 |
| World Bank Infrastructure Indicators | 50 | 1960–2024 |
| World Bank Energy & Mining Indicators | 41 | 1962–2024 |
| PSA 2024 Census Regional Density | 18 regions | 2024 |

## Temporal Alignment

Core analysis window is **~2017–2020**. The 2–3 year spread across datasets is standard in spatial economics.

| Dataset | Year | Gap from Zone Data (2017) |
|---|---|---|
| PEZA zone lists | Nov 2017 | Baseline |
| VIIRS nightlights | 2018 | +1 year (minor) |
| WorldPop population | 2020 | +3 years (minor) |
| GHSL built-up/pop | 2020 | +3 years (minor) |
| HDX census | 2015 | -2 years (minor) |
| Hansen forest baseline | 2000 | -17 years (**significant** — but lossyear allows reconstruction) |
| OSM infrastructure | 2026 | +9 years (**moderate** — major infrastructure is long-lived) |

## Methodology

### Part 1: Zone Dataset Construction

1. Loaded **47 World Bank** zones with GPS coordinates and operational dates (1974–2014)
2. Loaded **74 PEZA manufacturing** + **28 agro-industrial** zones (text locations only)
3. Loaded **12 Wikipedia freeport** zones as supplementary
4. Fuzzy-matched zone names across all sources (Jaro-Winkler distance < 0.25) — **77 matches**
5. Geocoded **27 unmatched zones** to municipality centroids using GADM level 2 boundaries
6. Cross-validated with Ravago et al. locatorid encoding (26 ecozones across 8 provinces)
7. Final dataset: **102 geocoded zones** (75 with WB coordinates, 27 with municipality centroids)

### Part 2: Municipality-Level Analysis Units

1. Loaded **1,628 municipalities/cities** from GADM v4.1 level 2 (excluding waterbodies)
2. Spatial join: assigned zone indicators (has_zone, zone_count, zone_area) to municipalities
3. Extracted raster statistics per municipality using `exactextractr`:
   - WorldPop: mean population density and total population
   - VIIRS: mean and median nighttime radiance
   - GHSL: mean built-up surface fraction (normalized 0–1)
4. Computed distances (EPSG:3123 projected, in km):
   - Distance to nearest airport (57 Philippine large/medium airports)
   - Distance to nearest primary road (41,623 OSM trunk/primary/motorway segments)
5. Result: **1,628 municipalities with 17 variables**

### Part 3: Zone vs Non-Zone Comparison

- **56 zone municipalities** vs **1,572 non-zone municipalities**
- Welch's t-tests for difference in means across all variables
- Correlation matrix of zone status with all characteristics
- Logistic regression: predictors of zone presence
- 6 visualizations: boxplots, scatter plot, bar chart, correlation matrix, establishment timeline

### Part 4: Dynamic Extension

- **73 zones** have establishment years (1974–2014) from World Bank matching
- **22 zones** have PEZA Board approval and registration dates
- Time-stamped outcomes available: VIIRS (2012–2023), WorldPop (2000–2020), Hansen lossyear (2001–2024), GHSL multi-epoch (1975–2020)
- Proposed empirical design: Staggered difference-in-differences with municipality and year fixed effects

## Key Findings

| Characteristic | Zone Municipalities (N=56) | Non-Zone Municipalities (N=1,572) | Difference | p-value | Sig |
|---|---|---|---|---|---|
| Population density (WorldPop 2020) | 2,570 persons/km² | 646 persons/km² | +1,924 | 0.002 | *** |
| Nighttime lights (VIIRS 2018) | 3.52 nW/cm²/sr | 0.55 nW/cm²/sr | +2.97 | <0.001 | *** |
| Built-up fraction (GHSL 2020) | 0.054 | 0.013 | +0.041 | <0.001 | *** |
| Distance to primary road | 3.0 km | 8.5 km | -5.5 km | <0.001 | *** |
| Distance to airport | 34.8 km | 42.6 km | -7.8 km | 0.080 | * |

**Significance:** *** p<0.01, ** p<0.05, * p<0.10

**Interpretation:** Industrial zones are systematically located in more urbanized, better-connected, and economically active municipalities. Zone municipalities have **4x higher population density**, **6x higher nighttime radiance**, and are **5.5 km closer to primary roads** than non-zone municipalities. Distance to airport is marginally significant (p=0.08). These differences are descriptive — zone placement is a deliberate policy choice driven by proximity to infrastructure and labor markets.

## Statistical Tests Performed

| # | Test | Purpose | Variables | Result |
|---|---|---|---|---|
| 1 | **Welch's t-test** (two-sample, unequal variance) | Compare means between zone vs non-zone municipalities | pop_density_mean_2020 | p=0.002 *** |
| 2 | **Welch's t-test** | Compare means | nightlights_mean_2018 | p<0.001 *** |
| 3 | **Welch's t-test** | Compare means | builtup_fraction_2020 | p<0.001 *** |
| 4 | **Welch's t-test** | Compare means | dist_nearest_primary_road_km | p<0.001 *** |
| 5 | **Welch's t-test** | Compare means | dist_nearest_airport_km | p=0.080 * (marginal) |
| 6 | **Pearson correlation matrix** | Identify linear associations between zone status and all municipality characteristics | has_zone + 5 continuous variables | Strongest: nightlights (r=+0.25), builtup (r=+0.24), pop_density (r=+0.18) |
| 7 | **Logistic regression (GLM, binomial)** | Identify which characteristics best predict zone presence (multivariate) | has_zone ~ pop_density + nightlights + builtup + dist_airport + dist_road | dist_road strongest predictor (coef=-0.92); builtup second (+0.65); model accuracy 97% |

**Notes on statistical approach:**
- Welch's t-test (not Student's) used because zone (N=56) and non-zone (N=1,572) groups have very unequal sample sizes
- Logistic regression uses all predictors simultaneously — controls for collinearity between variables
- All tests are descriptive/associational, NOT causal — see Limitations section
- Model accuracy of 97% is driven by class imbalance (97% of municipalities have no zone), not model quality

## ArcGIS Pro Workflow

The assignment requires: *"If you use a GIS tool, include enough documentation that the steps are understandable and reproducible."*

**Prerequisites:** ArcGIS Pro installed with an organizational account (e.g., university). Living Atlas access confirmed.

**Boundary data:** Use GADM shapefiles at `raw datasets/gadm/gadm41_PHL_2.shp` (municipalities) and `gadm41_PHL_1.shp` (provinces). These are generated by analysis.R using the `geodata` R package. The Philippines JSON Maps GeoJSON files do NOT load correctly in ArcGIS Pro — use GADM instead.

### Step 0: Getting Started with ArcGIS Pro (for beginners)

1. **Open ArcGIS Pro** on Windows → click **Map** under "New → Blank Templates"
2. You'll see a world map. The **Contents** pane is on the left (layer list), the **Catalog** pane is on the right.
3. **Catalog pane → Portal tab → globe icon** = Living Atlas (search for pre-loaded layers)
4. **To add local data:** Map tab → **Add Data** button → browse to your file
5. **Layer order matters:** In Contents pane, drag layers up/down. Points should be above polygons.
6. **If things look wrong:** Right-click a layer → **Zoom to Layer**
7. **Save often:** Ctrl+S

### Map 1: Zone Locations

1. **Map tab → Add Data** → navigate to `raw datasets/gadm/gadm41_PHL_2.shp` → OK
   - Municipality boundaries appear as polygons
2. **Map tab → Add Data → dropdown arrow → XY Point Data**
   - Browse to `zones.csv` → OK
   - X Field: `longitude`, Y Field: `latitude`
   - Coordinate System: `GCS_WGS_1984` (should auto-detect) → OK
   - Zone dots appear on the map
3. **Right-click zones layer → Symbology** (pane opens on right)
   - Change "Single Symbol" dropdown to **Unique Values**
   - Field 1: select `zone_type` → click **Apply**
   - Each zone type gets a different color
   - Click color swatches to customize: blue = manufacturing, green = agro-industrial, orange = freeport
4. **Map tab → Basemap dropdown** → choose **Light Gray Canvas** or **Topographic**
5. **Right-click municipality layer → Zoom to Layer** to frame the Philippines
6. **Insert tab → New Layout** → choose Letter or A4 size
7. **Insert tab → Map Frame** → draw rectangle on layout → map appears
8. **Insert → Legend** → click to place; **Insert → Scale Bar** → click to place; **Insert → North Arrow** → click to place
9. **Insert → Text** → type: "Industrial Zone Locations in the Philippines"
10. **Share tab → Export Layout** → PNG or PDF, 300 DPI

### Map 2: Zone vs Non-Zone Choropleth (Nightlights)

1. Add `raw datasets/gadm/gadm41_PHL_2.shp` (municipality boundaries)
2. **Right-click municipality layer → Joins and Relates → Add Join**
   - Input Join Field: `GID_2` (from GADM shapefile)
   - Join Table: browse to `analysis_units.csv`
   - Join Table Field: `gadm_id`
   - Click **OK** — data is now joined
3. **Right-click municipality layer → Symbology**
   - Change to **Graduated Colors**
   - Field: scroll to `nightlights_mean_2018`
   - Classification: **Natural Breaks (Jenks)**, 5 classes
   - Color Ramp: choose **Yellow to Red** gradient → Apply
   - Darker/redder = more nighttime light = more economic activity
4. Add `zones.csv` as XY Point Data (same as Map 1 step 2)
   - Change symbology to solid **black dots** (small, 4pt) so they stand out
5. **Optional:** Catalog → Portal → Living Atlas → search "VIIRS nighttime" → drag onto map for satellite context
6. Create layout and export (same as Map 1 steps 6–10)

### Map 3: Infrastructure and Distance

1. Add `raw datasets/gadm/gadm41_PHL_2.shp` (municipality boundaries)
2. **Add OSM roads:** Map tab → Add Data → `raw datasets/philippines-260503-free/gis_osm_roads_free_1.shp`
   - This loads ALL roads (very dense). To show only major roads:
   - Right-click roads layer → **Properties** → **Definition Query** tab
   - Click **New Definition Query**
   - Set: `fclass is equal to trunk` → click green **+**
   - Add: `OR fclass is equal to primary` → click green **+**
   - Add: `OR fclass is equal to motorway` → **Apply**
   - Now only major roads display
3. **Add airports:** Map tab → Add Data → XY Point Data → `raw datasets/airports.csv`
   - X: `longitude_deg`, Y: `latitude_deg`
   - Right-click → Properties → Definition Query: `iso_country is equal to PH AND type is equal to large_airport`
   - Symbology: airplane symbol or red triangles
4. Join `analysis_units.csv` to municipalities (same as Map 2 step 2)
5. Symbology → Graduated Colors on `dist_nearest_airport_km`
   - Color ramp: **Blue (close) to Red (far)**
6. Overlay zone points from `zones.csv` (black dots)
7. Create layout and export

### Map 4: Protected Areas and Zones

1. Add `raw datasets/gadm/gadm41_PHL_2.shp` (municipality boundaries)
2. **Map tab → Add Data** → `raw datasets/protected_conserved_areas_wdpca_polygons.geojson`
   - Green polygons appear showing national parks, reserves, sanctuaries
3. **Make semi-transparent:** Click protected areas layer → **Appearance tab** (in ribbon) → set **Transparency** slider to ~50%
4. Symbology: click color swatch → choose **dark green** fill
5. Add zone points from `zones.csv` (orange/red circles)
6. Look for zones near or inside protected areas — these face environmental constraints
7. Create layout and export

### Map 5: Population Density Choropleth (Optional)

1. Add municipality boundaries + join analysis_units.csv (same as Map 2)
2. Symbology → Graduated Colors on `pop_density_mean_2020`
3. Classification: Natural Breaks, 5 classes
4. Color ramp: Light Yellow to Dark Brown
5. Overlay zone points
6. Create layout and export

### Using Living Atlas Layers (Optional Enhancement)

1. **Catalog pane → Portal tab → globe icon** (Living Atlas)
2. Search for these layers and drag onto any map:
   - `"VIIRS nighttime lights"` — satellite nightlight imagery
   - `"WorldPop population"` — population density raster
   - `"World Surface Water"` — JRC water bodies
   - `"Global Forest Watch Loss Year"` — forest loss
3. These are pre-styled and ready to use — great for visual context behind your zone points

## File Descriptions

| File | Description |
|---|---|
| `sources.csv` | Source audit table — 19 sources with 8 columns each |
| `zones.csv` | 102 industrial zones with coordinates, type, area, source |
| `analysis_units.csv` | 1,628 municipalities with zone indicators and 17 variables |
| `analysis.R` | Reproducible R script covering Parts 1–4 |
| `app.R` | Interactive Shiny dashboard (deployed to shinyapps.io) |
| `figures/` | 6 visualization outputs (PNG) |
| `memo.pdf` | 2-page summary memo (user-created) |
| `CLAUDE.md` | Project guidance for Claude Code |
| `Difficulties_Claude.txt` | Data access challenges and link verification (32 sources checked) |
| `raw datasets/DOWNLOAD_NOTES.txt` | Detailed raster download documentation (20 files, 18.1 GB) |
| `raw datasets/` | All downloaded data files (~24 GB locally, excluded from git) |

## How to Reproduce

### Prerequisites

- R 4.5+ with packages: `sf`, `terra`, `exactextractr`, `dplyr`, `tidyr`, `readxl`, `stringdist`, `ggplot2`, `corrplot`, `readr`, `jsonlite`, `geodata`
- ArcGIS Pro with organizational account (for map generation — optional)

### Install R packages

```r
install.packages(c("sf", "terra", "exactextractr", "dplyr", "tidyr",
                    "readxl", "stringdist", "ggplot2", "corrplot",
                    "readr", "jsonlite", "geodata"))
```

### Download data

All data sources are documented in `sources.csv` with direct download links. Key downloads:

1. **PEZA zone files:** `peza.gov.ph/sites/default/files/1.xls` and `3.xls` (SSL bypass: `curl -k`)
2. **World Bank SEZ:** `datacatalog.worldbank.org/search/dataset/0037742` → filter for Philippines
3. **GADM boundaries:** Auto-downloaded by analysis.R via `geodata::gadm()` — or manually from gadm.org
4. **Raster data:** see `raw datasets/DOWNLOAD_NOTES.txt` for tile-by-tile download instructions
5. Place all files in `raw datasets/` folder structure

### Run analysis

```bash
cd SEZ-Spatial-Data-Research
Rscript analysis.R
```

This produces `zones.csv`, `analysis_units.csv`, GADM shapefiles, and all figures in `figures/`.

### Run Shiny dashboard locally

```r
shiny::runApp("app.R")
```

### Deploy to shinyapps.io

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(name = "YOUR_NAME", token = "YOUR_TOKEN", secret = "YOUR_SECRET")
rsconnect::deployApp(".", appFiles = c("app.R", "zones.csv", "analysis_units.csv", "sources.csv"))
```

## Limitations

1. **Selection bias:** Zones were intentionally placed near infrastructure and cities — observed differences are descriptive, not causal
2. **Geocoding imprecision:** 27 zones without GPS coordinates were geocoded to municipality centroids, introducing spatial error of up to several kilometers
3. **Temporal gaps:** Zone data (2017), nightlights (2018), population (2020) — 2–3 year cross-sectional spread
4. **Infrastructure timing:** OSM roads/airports reflect 2026 state; some infrastructure may post-date zone establishment
5. **Island geography:** Euclidean distances do not account for water crossings in the Philippine archipelago
6. **Missing zone types:** IT Parks (262), Tourism Zones (19), and Medical Tourism Parks (2) are not individually listed in available public data
7. **Missing data:** Land values not available; PSA municipality-level economic data blocked (HTTP 403); post-2017 zones not captured
8. **Airport distance marginal:** Distance to nearest airport is only marginally significant (p=0.08) — zones are not systematically closer to airports

## AI Disclosure

Claude Code (Anthropic, Claude Opus 4.6) was used for:
- Dataset research, URL verification, and academic literature search
- Data processing code generation (analysis.R, app.R)
- Documentation writing (CLAUDE.md, README.md, Difficulties_Claude.txt)
- Source audit table construction (sources.csv)
- Shiny dashboard development and deployment

All analytical decisions, research framing, and interpretation are the author's own.

## License

MIT License. See `LICENSE` file.
