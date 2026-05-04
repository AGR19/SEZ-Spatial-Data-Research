# Philippines Industrial Zones: Spatial Data Research

Stanford IRISS Predoctoral Research Assignment — Place-Based Industrial Policy and Development

## Research Question

Where are industrial zones located in the Philippines, and how do zone locations differ from non-zone locations in terms of population density, nighttime economic activity, infrastructure proximity, and land cover?

**Country:** Philippines
**Spatial unit of analysis:** Municipality (~1,618 units)
**Coordinate Reference System:** EPSG:4326 (WGS 84) for storage; EPSG:3123 (PRS 92) for distance calculations
**Primary language:** R
**GIS tool:** ArcGIS Pro (with Living Atlas via Arizona State University account)

## Assignment Part Mapping

| Assignment Part | Deliverable | analysis.R Sections |
|---|---|---|
| **Part 1:** Find and construct zone data | `zones.csv` (93 zones) | Sections 1.1–1.8 |
| **Part 2:** Merge additional spatial/economic data | `analysis_units.csv` (1,618 municipalities, 17 variables) | Sections 2.1–2.8 |
| **Part 3:** Compare zone and non-zone locations | Summary stats table, logistic regression, 6 figures | Sections 3.1–3.5 |
| **Part 4:** Dynamic and causal extension | Establishment year timeline, proposed DiD design | Sections 4.1–4.3 |

## Data Sources (19 total)

See `sources.csv` for the complete source audit table with links, types, variables, credibility, limitations, and next steps.

### Zone Data (Primary)

| Source | Zones | Has Coordinates | Has Est. Year |
|---|---|---|---|
| PEZA Manufacturing Zones (1.xls) | 74 | No — geocoded to municipality centroids | No |
| PEZA Agro-Industrial Zones (3.xls) | 22 + 6 proclaimed | No — geocoded to municipality centroids | PEZA approval dates |
| World Bank CIIP SEZ Database | 47 | Yes (lat/lon) | Yes (1974–2014) |
| Wikipedia Economic Zones List | 30 | No | No |
| Ravago et al. (2021) Mendeley Data | 26 ecozones (115 firms) | Locatorid encoding (province-city-zone) | No |

### Spatial and Economic Data

| Dataset | Resolution | Time Period | Used For |
|---|---|---|---|
| WorldPop Population Density | ~1 km | 2020 | Population density per municipality |
| VIIRS Nighttime Lights | ~500 m | 2018 | Economic activity proxy |
| GHSL Built-up Surface | ~1 km | 2020 | Urbanization measure |
| Hansen Global Forest Change | 30 m | 2000 baseline, loss 2001–2024 | Forest cover |
| JRC Global Surface Water | 30 m | 1984–2021 cumulative | Water body identification |
| OpenStreetMap Philippines | Vector | 2026 snapshot | Roads, waterways, ports, transport |
| OurAirports | Point CSV | 2026 snapshot | Airport locations and distances |
| HDX 2015 Census Population | Barangay | 2015 | Census population by municipality |
| WDPCA Protected Areas | Polygon | 1919–2021 | Protected area overlap |
| Philippines JSON Maps | GeoJSON | 2023 PSGC | Municipality boundaries |

### Economic Context (Country-level)

| Dataset | Indicators | Time Period |
|---|---|---|
| World Bank Development Indicators | 1,486 | 1960–2025 |
| World Bank Infrastructure Indicators | 50 | 1960–2024 |
| World Bank Energy & Mining Indicators | 41 | 1962–2024 |
| PSA 2024 Census Regional Density | 18 regions | 2024 |

## Temporal Alignment

Core analysis window is **~2017–2020**. Zone data is from 2017 (PEZA), nightlights from 2018 (VIIRS), population/built-up from 2020 (WorldPop/GHSL). The 2–3 year spread is standard in spatial economics. Hansen forest baseline is 2000 but lossyear data (2001–2024) allows reconstruction to any year. OSM infrastructure reflects 2026 state — major ports and airports are long-lived infrastructure. All temporal gaps are documented transparently.

## Methodology

### Part 1: Zone Dataset Construction

1. Loaded 47 World Bank zones with GPS coordinates and operational dates
2. Loaded 74 PEZA manufacturing + 28 agro-industrial zones (text locations only)
3. Fuzzy-matched zone names across sources (Jaro-Winkler distance < 0.25) — **72 matches**
4. Geocoded 20 unmatched PEZA zones to municipality centroids using Philippines JSON Maps boundaries
5. Cross-validated with Ravago et al. locatorid encoding (26 ecozones across 8 provinces)
6. Final dataset: **93 geocoded industrial zones**

### Part 2: Municipality-Level Analysis Units

1. Loaded 1,618 municipality boundaries from Philippines JSON Maps (PSGC-coded)
2. Spatial join: assigned zone indicators (has_zone, zone_count, zone_area) to municipalities
3. Extracted raster statistics per municipality using `exactextractr`:
   - WorldPop: mean population density and total population
   - VIIRS: mean and median nighttime radiance
   - GHSL: mean built-up surface fraction
4. Computed distances (EPSG:3123 projected, in km):
   - Distance to nearest airport (57 Philippine large/medium airports)
   - Distance to nearest primary road (41,623 OSM trunk/primary/motorway segments)
5. Result: **1,618 municipalities with 17 variables**

### Part 3: Zone vs Non-Zone Comparison

- **48 zone municipalities** vs **1,570 non-zone municipalities**
- Welch's t-tests for difference in means across all variables
- Correlation matrix of zone status with all characteristics
- Logistic regression: predictors of zone presence
- 6 visualizations: boxplots, scatter plot, bar chart, correlation matrix, establishment timeline

### Part 4: Dynamic Extension

- **47 zones** have establishment years (1974–2014) from World Bank
- **22 zones** have PEZA Board approval and registration dates
- Time-stamped outcomes available: VIIRS (2012–2023), WorldPop (2000–2020), Hansen lossyear (2001–2024), GHSL multi-epoch (1975–2020)
- Proposed empirical design: Staggered difference-in-differences with municipality and year fixed effects

## ArcGIS Pro Workflow

The assignment requires: *"If you use a GIS tool, include enough documentation that the steps are understandable and reproducible."*

### Map 1: Zone Locations

1. Open ArcGIS Pro → New Map
2. Add Data → navigate to `raw datasets/philippines-json-maps-master/2023/geojson/provdists/hires/` → add all municipality boundary JSON files
3. Add `zones.csv` as XY Event Layer (longitude, latitude fields, EPSG:4326)
4. Symbology → Unique Values on `zone_type` field (manufacturing = blue, agro-industrial = green, freeport = orange)
5. Add Living Atlas basemap: World Topographic Map
6. Zoom to Philippines extent (116–127°E, 5–21°N)
7. Insert Layout → add title "Industrial Zone Locations in the Philippines", legend, scale bar, north arrow
8. Share → Export Layout as PNG/PDF

### Map 2: Zone vs Non-Zone Choropleth (Nightlights)

1. Right-click municipality layer → Joins and Relates → Add Join
2. Join Field: use `adm3_psgc` from boundaries, `psgc_code` from `analysis_units.csv`
3. Symbology → Graduated Colors on `nightlights_mean_2018`
4. Classification method: Natural Breaks (Jenks), 5 classes
5. Color ramp: Yellow to Red
6. Add `zones.csv` as overlay points (black dots)
7. Add Living Atlas layer: VIIRS Nighttime Lights (for satellite imagery context)
8. Export as PNG/PDF

### Map 3: Distance to Infrastructure

1. Add OSM roads layer (`raw datasets/philippines-260503-free/gis_osm_roads_free_1.shp`)
2. Definition Query: `fclass IN ('trunk', 'primary', 'motorway')`
3. Add airport points from `raw datasets/airports.csv` (XY Event Layer, filter `iso_country = 'PH'` and `type IN ('large_airport', 'medium_airport')`)
4. Symbology: municipality boundaries colored by `dist_nearest_airport_km` (Graduated Colors)
5. Overlay zone points from `zones.csv`
6. Export as PNG/PDF

### Map 4: Protected Areas and Zones

1. Add `raw datasets/protected_conserved_areas_wdpca_polygons.geojson`
2. Symbology: semi-transparent green fill for protected areas
3. Overlay zone points and municipality boundaries
4. Identify any zones located near or inside protected areas
5. Export as PNG/PDF

## File Descriptions

| File | Description |
|---|---|
| `sources.csv` | Source audit table — 19 sources with 8 columns each |
| `zones.csv` | 93 industrial zones with coordinates, type, area, source |
| `analysis_units.csv` | 1,618 municipalities with zone indicators and 17 variables |
| `analysis.R` | Reproducible R script covering Parts 1–4 |
| `figures/` | 6 visualization outputs (PNG) |
| `memo.pdf` | 2-page summary memo (user-created) |
| `CLAUDE.md` | Project guidance for Claude Code |
| `Claude_TG_Insight.txt` | Internal methodology notes (not for submission) |
| `Claude_Fireline_Learning.txt` | Coding style reference |
| `Difficulties_Claude.txt` | Data access challenges and link verification |
| `raw datasets/DOWNLOAD_NOTES.txt` | Detailed raster download documentation |
| `raw datasets/` | All downloaded data files (~24 GB locally, excluded from git) |

## How to Reproduce

### Prerequisites

- R 4.5+ with packages: `sf`, `terra`, `exactextractr`, `dplyr`, `tidyr`, `readxl`, `stringdist`, `ggplot2`, `corrplot`, `readr`, `jsonlite`
- ArcGIS Pro (for map generation — optional)

### Install R packages

```r
install.packages(c("sf", "terra", "exactextractr", "dplyr", "tidyr",
                    "readxl", "stringdist", "ggplot2", "corrplot",
                    "readr", "jsonlite"))
```

### Download data

All data sources are documented in `sources.csv` with direct download links. Key downloads:

1. PEZA zone files: `peza.gov.ph/sites/default/files/1.xls` and `3.xls` (SSL bypass: `curl -k`)
2. World Bank SEZ: `datacatalog.worldbank.org/search/dataset/0037742` (filter for Philippines)
3. Raster data: see `raw datasets/DOWNLOAD_NOTES.txt` for tile-by-tile download instructions
4. Place all files in `raw datasets/` folder structure

### Run analysis

```bash
cd SEZ-Spatial-Data-Research
Rscript analysis.R
```

This produces `zones.csv`, `analysis_units.csv`, and all figures in `figures/`.

## Key Findings

| Characteristic | Zone Municipalities | Non-Zone Municipalities | Significant? |
|---|---|---|---|
| Population density (WorldPop 2020) | Higher | Lower | See analysis.R output |
| Nighttime lights (VIIRS 2018) | Higher | Lower | See analysis.R output |
| Distance to airport | Closer | Farther | See analysis.R output |
| Distance to primary road | Closer | Farther | See analysis.R output |
| Built-up fraction (GHSL 2020) | Higher | Lower | See analysis.R output |

Industrial zones are systematically located in more urbanized, better-connected, and economically active municipalities. This is descriptive — zone placement is a policy choice driven by proximity to infrastructure and labor markets.

## Limitations

1. **Selection bias:** Zones were intentionally placed near infrastructure and cities — observed differences are descriptive, not causal
2. **Geocoding imprecision:** ~20 zones without GPS coordinates were geocoded to municipality centroids, introducing spatial error of up to several kilometers
3. **Temporal gaps:** Zone data (2017), nightlights (2018), population (2020) — 2–3 year cross-sectional spread
4. **Infrastructure timing:** OSM roads/airports reflect 2026 state; some infrastructure may post-date zone establishment
5. **Island geography:** Euclidean distances do not account for water crossings in the Philippine archipelago
6. **Missing data:** Land values not available; PSA municipality-level economic data blocked (HTTP 403); post-2017 zones not captured

## AI Disclosure

Claude Code (Anthropic, Claude Opus 4.6) was used for:
- Dataset research and URL verification
- Data processing code generation (analysis.R)
- Documentation writing (CLAUDE.md, README.md, Difficulties_Claude.txt)
- Source audit table construction (sources.csv)

All analytical decisions, research framing, and interpretation are the author's own.

## License

MIT License. See `LICENSE` file.
