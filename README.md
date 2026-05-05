# Philippines Industrial Zones: Spatial Data Construction and Descriptive Analysis

**Adishesh Gonibeed Ravishankar** - Stanford Predoctoral IRiSS Assignment - Dr. Tishara Garg

---

## 1. Summary

I chose the **Philippines** for having a moderately higher GDP than other developing nations. It is also a newly industrialized country (NIC) having a mostly agrarian economy.¹ To study where industrial zones are located, I assembled a spatial dataset of 102 zones from government and international sources, linked it to satellite-derived and infrastructure data at the municipality level, and compared zone versus non-zone locations descriptively. The analysis suggests that industrial zones are systematically located in municipalities with higher population density, greater nighttime economic activity, and closer proximity to primary road networks. This is a partial solution - further work is needed to verify data accuracy and address missing datasets.

## 2. Background and Motivation

The Philippines enacted the Special Economic Zone Act of 1995 (Republic Act 7916), establishing the Philippine Economic Zone Authority (PEZA) as the coordinating body for industrial zone development.⁵ PEZA currently administers over 300 economic zones of various types, with manufacturing and agro-industrial zones being the primary vehicles for industrial development and foreign direct investment attraction (Ortega et al., 2015).

Understanding *where* these zones are placed - and how those locations differ from non-zone areas - is foundational to studying whether place-based industrial policy shapes local economic outcomes. This analysis constructs the spatial dataset necessary for such an inquiry.

## 3. Prior Work

Ortega, Acielo, and Hermida (2015) conducted the most directly relevant prior study, mapping emergent mega-regions in the Philippines using municipal-level census data (1990, 2000, 2010) overlaid with PEZA zone locations and road networks. They identified 11 mega-regions and demonstrated that PEZA zones cluster in high-density municipalities along major transport corridors. However, their work did not produce a publicly available geocoded dataset of zone locations. The present analysis fills this gap by constructing a reproducible spatial dataset with coordinates for 102 industrial zones.

## 4. Results

- **GitHub Repository:** [https://github.com/AGR19/SEZ-Spatial-Data-Research](https://github.com/AGR19/SEZ-Spatial-Data-Research)
- **Live Interactive Dashboard (Bonus):** [https://agr19.shinyapps.io/philippines-industrial-zones/](https://agr19.shinyapps.io/philippines-industrial-zones/)
- **R-Generated Statistical Figures:** [figures/](https://github.com/AGR19/SEZ-Spatial-Data-Research/tree/main/figures)
- **ArcGIS Pro Maps:** [Result Maps ArcGIS/](https://github.com/AGR19/SEZ-Spatial-Data-Research/tree/main/Result%20Maps%20ArcGIS)

*Note: The Shiny dashboard is a bonus deliverable beyond assignment requirements, demonstrating interactive spatial data exploration.*

## 5. Sources Reviewed

Twenty data sources were identified, evaluated, and documented in `sources.csv`. Key sources:

1. **PEZA Manufacturing Zones** (peza.gov.ph/sites/default/files/1.xls) - 74 zones with names, locations, area
2. **PEZA Agro-Industrial Zones** (peza.gov.ph/sites/default/files/3.xls) - 22 operating + 6 proclaimed
3. **World Bank CIIP SEZ Database** (datacatalog.worldbank.org) - 47 zones with GPS coordinates and establishment years
4. **GADM Philippines v4.1** (gadm.org via R geodata package) - municipality boundaries
5. **VIIRS Nighttime Lights 2018** (eogdata.mines.edu) - economic activity proxy
6. **WorldPop Population 2020** (worldpop.org) - population density raster
7. **GHSL Built-up Surface 2020** (human-settlement.emergency.copernicus.eu) - urbanization
8. **OpenStreetMap Philippines** (download.geofabrik.de) - roads, waterways, transport infrastructure
9. **OurAirports** (ourairports.com) - airport locations with coordinates

**Pain Points Encountered:**
1. Some government websites (even the one cited on Wikipedia itself) were not operational.¹ ²
2. Philippines Statistics Authority's OpenStat³ websites - some were not working, only a few worked. I could do queries on the table but I was not able to download the csv files. (Showed Cloudflare Error 520) or PXWeb Errors when I open some datasets. Wish I had this data. The quality and the micro/macroeconomic segments of datasets were too good!
3. GADM⁴ download links not working. Had to download it via R geodata package.

## 6. Methods

**Spatial unit:** Municipality (GADM level 2, 1,628 units)
**CRS:** EPSG:4326 (WGS 84) for storage; EPSG:3123 (PRS 92) for distance calculations
**Tools:** R 4.5.1 + ArcGIS Pro (with Living Atlas)

| Step | What was done | So what |
|---|---|---|
| Zone construction | Fuzzy-matched zone names across 5 sources (Jaro-Winkler < 0.25), geocoded 27 unmatched zones to municipality centroids | Produced first geocoded dataset of 102 Philippine industrial zones |
| Spatial merge | Extracted raster statistics (population, nightlights, built-up area) per municipality; computed distances to airports and primary roads | Created municipality-level dataset linking zone presence to observable characteristics |
| Comparison | Welch's t-tests, Pearson correlations, logistic regression | Quantified how zone and non-zone municipalities differ on 5 characteristics |
| Dynamic extension | Compiled establishment years for 73 zones; identified annual VIIRS/WorldPop as panel data | Documented feasibility of causal staggered DiD design |

## 7. Findings

| Characteristic | Zone (N=56) | Non-Zone (N=1,572) | Difference | p-value |
|---|---|---|---|---|
| Population density (persons/km²) | 2,570 | 646 | +1,924 | 0.002*** |
| Nighttime lights (nW/cm²/sr) | 3.52 | 0.55 | +2.97 | <0.001*** |
| Built-up fraction | 0.054 | 0.013 | +0.041 | <0.001*** |
| Distance to primary road (km) | 3.0 | 8.5 | -5.5 | <0.001*** |
| Distance to airport (km) | 34.8 | 42.6 | -7.8 | 0.080* |

**Key takeaway:** Industrial zones are located in municipalities that are already more urbanized and better-connected. The strongest predictor of zone presence is proximity to primary roads (logistic regression coefficient = -0.92). This is consistent with zones being placed to leverage existing infrastructure rather than to develop new areas from scratch.

## 8. Conclusions

The data suggest that Philippine industrial zones reinforce existing urban-industrial corridors rather than creating new development poles in remote areas. This is descriptive, not causal - zones were intentionally placed near infrastructure. A causal analysis using staggered difference-in-differences, exploiting variation in establishment timing (1974–2014), would be the natural next step to determine whether zones *cause* local economic growth or merely *reflect* pre-existing advantages.

**This is a partial solution.** Next steps include verifying data accuracy, handling missing datasets, and obtaining complete PEZA zone coordinates via Freedom of Information request.

## 9. Limitations and Future Directions

**Current limitations:**
1. Selection bias - zones placed deliberately near infrastructure; correlation ≠ causation
2. Geocoding imprecision - 27 zones approximated to municipality centroids
3. Temporal gaps - zone data (2017), nightlights (2018), population (2020)
4. Island geography - Euclidean distances do not account for water crossings
5. Missing zone types - IT Parks (262), Tourism Zones (19) not individually listed in public data

**With more time, I would:**
- File a Freedom of Information request to PEZA for complete zone coordinates
- Download multi-year VIIRS composites (2012–2023) for panel difference-in-differences
- Obtain municipality-level economic data from PSA (employment, firm counts by sector)
- Extract BIR zonal land values from gazette PDFs
- Conduct propensity score matching for credible control group construction

## 10. Software and Versions

| Software | Version | Purpose |
|---|---|---|
| R | 4.5.1 | Primary analysis language |
| sf | 1.1.0 | Spatial vector operations |
| terra | 1.9.11 | Raster operations |
| exactextractr | 0.10.1 | Fast zonal statistics |
| dplyr | 1.1.4 | Data manipulation |
| ggplot2 | 3.5.2 | Visualization |
| stringdist | 0.9.17 | Fuzzy name matching |
| geodata | 0.6.9 | GADM boundary download |
| corrplot | 0.95 | Correlation matrix visualization |
| shiny | 1.13.0 | Interactive dashboard |
| leaflet | 2.2.3 | Interactive maps |
| plotly | 4.12.0 | Interactive charts |
| ArcGIS Pro | 3.x | Map generation (Living Atlas) |

## 11. References

Ortega, A.A., Acielo, J.M.A.E., & Hermida, M.C.H. (2015). Mega-regions in the Philippines: Accounting for special economic zones and global-local dynamics. *Cities*, 48, 130–139. https://doi.org/10.1016/j.cities.2015.07.002

Philippine Economic Zone Authority (2017). *List of Operating Manufacturing Economic Zones*. Retrieved from https://www.peza.gov.ph/sites/default/files/1.xls

---

¹ Wikipedia contributors. (2002). *Economy of the Philippines*. https://en.wikipedia.org/wiki/Economy_of_the_Philippines
² https://www.peza.gov.ph/index.php/economic-zones/list-of-economic-zones/operating-economic-zones
³ https://openstat.psa.gov.ph/
⁴ https://gadm.org/download_country.html
⁵ Republic of the Philippines. (1995). *Republic Act No. 7916: Special Economic Zone Act of 1995*. https://www.peza.gov.ph/special-economic-zone-act

## 12. Statistical Tests and Results

| # | Test | Variables | Result |
|---|---|---|---|
| 1 | Welch's t-test | Population density (zone vs non-zone) | p=0.002 *** |
| 2 | Welch's t-test | Nighttime lights (zone vs non-zone) | p<0.001 *** |
| 3 | Welch's t-test | Built-up fraction (zone vs non-zone) | p<0.001 *** |
| 4 | Welch's t-test | Distance to primary road (zone vs non-zone) | p<0.001 *** |
| 5 | Welch's t-test | Distance to airport (zone vs non-zone) | p=0.080 * (marginal) |
| 6 | Pearson correlation | has_zone vs all characteristics | Strongest: nightlights (r=+0.25), builtup (r=+0.24) |
| 7 | Logistic regression (GLM) | has_zone ~ all predictors | dist_road strongest (coef=-0.92); model accuracy 97% |

**Notes:** Welch's t-test used due to unequal sample sizes (N=56 vs N=1,572). All tests are descriptive/associational, not causal. Model accuracy of 97% reflects class imbalance, not predictive power.

## 13. AI Disclosure

I used Claude Opus 4.6 with high effort (1M tokens) on Claude Code.

## License

MIT License. See `LICENSE` file.

---

# Technical Appendix: Reproduction Instructions

## Assignment Part Mapping

| Assignment Part | Deliverable | analysis.R Sections |
|---|---|---|
| **Part 1:** Find and construct zone data | `zones.csv` (102 zones) | Sections 1.1–1.8 |
| **Part 2:** Merge additional spatial/economic data | `analysis_units.csv` (1,628 municipalities) | Sections 2.1–2.8 |
| **Part 3:** Compare zone and non-zone locations | Summary stats, logistic regression, 6 figures | Sections 3.1–3.5 |
| **Part 4:** Dynamic and causal extension | Establishment timeline, proposed DiD design | Sections 4.1–4.3 |

## File Descriptions

| File | Description |
|---|---|
| `sources.csv` | Source audit table - 20 sources with 8 columns each |
| `zones.csv` | 102 industrial zones with coordinates, type, area, source |
| `analysis_units.csv` | 1,628 municipalities with zone indicators and 17 variables |
| `analysis.R` | Reproducible R script covering Parts 1–4 |
| `app.R` | Interactive Shiny dashboard (deployed to shinyapps.io) |
| `figures/` | 6 visualization outputs (PNG) |
| `Result Maps ArcGIS/` | 4 ArcGIS Pro maps (PDF) + results screenshot |

## How to Reproduce

### Prerequisites

- R 4.5+ with packages listed in Section 10
- ArcGIS Pro with organizational account (for map generation - optional)

### Install R packages

All package versions are listed in `requirements.txt`. Install with:

```r
install.packages(c("sf", "terra", "exactextractr", "dplyr", "tidyr",
                    "readxl", "stringdist", "ggplot2", "corrplot",
                    "readr", "jsonlite", "geodata", "shiny", "leaflet",
                    "DT", "plotly"))
```

### Download data

**Note:** `analysis.R` requires raw data files to be downloaded first. The `raw datasets/` folder is not in the repository (too large, ~24 GB). All data sources are documented in `sources.csv` with direct download links. Key downloads:

1. **PEZA zone files:** `peza.gov.ph/sites/default/files/1.xls` and `3.xls` (SSL bypass: `curl -k`)
2. **World Bank SEZ:** `datacatalog.worldbank.org/search/dataset/0037742` - filter for Philippines
3. **GADM boundaries:** Auto-downloaded by analysis.R via `geodata::gadm()`
4. **Raster data:** see `raw datasets/DOWNLOAD_NOTES.txt` for tile-by-tile download instructions
5. Place all files in `raw datasets/` folder following the structure in DOWNLOAD_NOTES.txt

### Run analysis

```bash
cd SEZ-Spatial-Data-Research
Rscript analysis.R
```

Produces `zones.csv`, `analysis_units.csv`, and all figures in `figures/`.

### Run Shiny dashboard locally

```r
shiny::runApp("app.R")
```

## ArcGIS Pro Workflow

**Boundary data:** Use GADM shapefiles at `raw datasets/gadm/gadm41_PHL_2.shp`. Generated by analysis.R via `geodata` R package. Philippines JSON Maps GeoJSON files do NOT load in ArcGIS Pro - use GADM instead.

### Map 1: Zone Locations
1. Map tab → Add Data → `raw datasets/gadm/gadm41_PHL_2.shp`
2. Add `zones.csv` as XY Point Data (longitude, latitude, EPSG:4326)
3. Symbology → Unique Values on `zone_type`
4. Add basemap (Light Gray Canvas)
5. Insert Layout → title, legend, scale bar, north arrow → Export

### Map 2: Zone vs Non-Zone Choropleth
1. Join `analysis_units.csv` to municipality boundaries (GID_2 = gadm_id)
2. Symbology → Graduated Colors on `nightlights_mean_2018` (Natural Breaks, 5 classes)
3. Overlay zone points → Export

### Map 3: Infrastructure and Distance
1. Add OSM roads (`gis_osm_roads_free_1.shp`, filter: trunk/primary/motorway)
2. Add airports from `airports.csv` (XY Point Data, filter: PH + large_airport)
3. Symbology on `dist_nearest_airport_km` → Export

### Map 4: Protected Areas
1. Add `protected_conserved_areas_wdpca_polygons.geojson`
2. Set 50% transparency, dark green fill
3. Overlay zone points → Export

## Technical Appendix

### Data Pipeline

1. **Zone identification:** PEZA Excel files parsed with `readxl`, World Bank CSV loaded with `readr`, Wikipedia data manually extracted to CSV.
2. **Name matching:** Zone names normalized (lowercase, stripped punctuation), then matched across sources using Jaro-Winkler string distance (`stringdist` package, threshold < 0.25).
3. **Geocoding:** Unmatched zones parsed for municipality names from location text, then fuzzy-matched to GADM level 2 boundary names. Municipality polygon centroids used as approximate coordinates (`sf::st_centroid`).
4. **Raster extraction:** WorldPop, VIIRS, and GHSL global rasters cropped to Philippines extent (116-128E, 4-22N), then zonal statistics extracted per municipality polygon using `exactextractr::exact_extract`.
5. **Distance computation:** Municipality centroids and infrastructure points (airports, road segments) reprojected to EPSG:3123 (PRS 92, meters), then minimum Euclidean distance computed with `sf::st_distance`.
6. **Statistical comparison:** Welch's t-test (`t.test` with `var.equal=FALSE`) for unequal groups; logistic regression via `glm(family=binomial)`; Pearson correlation via `cor()`.

### Folder Structure (local, not in repo)

```
raw datasets/
  peza_zones_raw.xls          # PEZA 74 manufacturing zones
  peza_locators_raw.xls       # PEZA 22+6 agro-industrial zones
  worldbank_sez_philippines.csv  # World Bank 47 zones (filtered)
  wikipedia_sez_data.csv      # Wikipedia 30 zones (extracted)
  airports.csv                # OurAirports global (filter for PH)
  gadm/                       # GADM boundaries (auto-downloaded by geodata)
  worldpop/                   # WorldPop Philippines 2020 (1.8 MB)
  viirs/                      # VIIRS 2018 nightlights (16.4 GB)
  ghsl/                       # GHSL built-up, population, SMOD (666 MB)
  hansen_forest/              # Hansen treecover2000 + lossyear (715 MB)
  jrc_water/                  # JRC surface water occurrence (317 MB)
  philippines-260503-free/    # OSM shapefiles (4.7 GB)
```

### CRS Details

- **Storage:** All vector data stored in EPSG:4326 (WGS 84, degrees)
- **Distance calculations:** Reprojected to EPSG:3123 (PRS 92, Philippine Reference System, meters) before computing distances
- **Rasters:** WorldPop, VIIRS, GHSL natively in EPSG:4326; GHSL SMOD in EPSG:54009 (Mollweide) requires reprojection
- **Why PRS 92:** Official Philippine projected coordinate system, provides accurate distance measurements in meters for the Philippine archipelago
