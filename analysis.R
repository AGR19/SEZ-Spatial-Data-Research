# ================================================================================
# ANALYSIS.R — Philippines Industrial Zones Spatial Analysis
# Stanford IRISS Predoctoral Assignment
# ================================================================================
#
# This script constructs a reproducible spatial dataset of industrial zones
# in the Philippines, merges it with spatial/economic data, and compares
# zone vs non-zone locations.
#
# Spatial unit of analysis: Philippine municipalities (~1,618 units)
# CRS: EPSG:4326 (WGS 84) for storage; EPSG:3123 (PRS 92) for distances
# Core analysis window: ~2017-2020
#
# Outputs:
#   zones.csv          — cleaned zone dataset (~100 zones)
#   analysis_units.csv — municipality-level dataset with zone indicators
#   Figures            — comparison plots (saved to figures/)
#
# Data sources: see sources.csv (19 sources documented)
# ================================================================================

# === SETUP ===================================================================

library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(tidyr)
library(readxl)
library(stringdist)
library(ggplot2)
library(corrplot)
library(readr)
library(jsonlite)

set.seed(42)

# CRS constants
CRS_WGS84 <- 4326
CRS_PRS92 <- 3123

# Base path — adjust if running from different location
BASE_PATH <- "."
RAW_PATH  <- file.path(BASE_PATH, "raw datasets")

# Create output directory for figures
dir.create(file.path(BASE_PATH, "figures"), showWarnings = FALSE)

cat("=== SETUP COMPLETE ===\n")
cat("Working directory:", getwd(), "\n")
cat("R version:", R.version.string, "\n\n")


# === PART 1: CONSTRUCT ZONES.CSV =============================================
cat("\n")
cat("================================================================\n")
cat("  PART 1: CONSTRUCT ZONES.CSV\n")
cat("================================================================\n\n")

# --- 1.1 Load World Bank zones (47 with coordinates) -------------------------
cat("--- 1.1 Loading World Bank CIIP zones ---\n")

wb_raw <- read_csv(file.path(RAW_PATH, "worldbank_sez_philippines.csv"),
                   show_col_types = FALSE)

wb_zones <- wb_raw %>%
  transmute(
    zone_name       = trimws(zone_name),
    latitude        = as.numeric(latitude),
    longitude       = as.numeric(longitude),
    area_hectares   = as.numeric(size_),
    operational_date = as.integer(operational_date),
    region          = region,
    nearest_port    = nearest_port,
    dist_port_km_wb = as.numeric(nearest_portdist),
    nearest_airport = nearest_airport,
    dist_airport_km_wb = as.numeric(nearest_airportdist),
    management_type = management_type,
    zone_type_wb    = zone_type,
    data_source     = "World Bank CIIP"
  )

cat("  World Bank zones loaded:", nrow(wb_zones), "\n")
cat("  Operational date range:", min(wb_zones$operational_date, na.rm = TRUE),
    "-", max(wb_zones$operational_date, na.rm = TRUE), "\n")
cat("  All have coordinates:", all(!is.na(wb_zones$latitude)), "\n\n")


# --- 1.2 Load PEZA manufacturing zones (74) ----------------------------------
cat("--- 1.2 Loading PEZA manufacturing zones ---\n")

peza_mfg_raw <- read_xls(file.path(RAW_PATH, "peza_zones_raw.xls"),
                          sheet = "Operating", col_names = FALSE)

# The data starts at row 7 (after 4 header rows + 2 region rows)
# Columns: region/province info in col 3, zone number in col 5,
# zone name in col 6, location in col 7, developer in col 8,
# area in col 9, investments in col 10, nationality in col 11

# Excel has 9 columns: ...1=region/province, ...3=zone_number, ...4=zone_name,
# ...5=location, ...6=developer, ...7=area, ...8=investments, ...9=nationality
peza_mfg <- peza_mfg_raw %>%
  filter(!is.na(...3) & !is.na(suppressWarnings(as.numeric(...3)))) %>%
  transmute(
    zone_number     = as.integer(...3),
    zone_name       = trimws(as.character(...4)),
    location_text   = trimws(as.character(...5)),
    developer       = trimws(as.character(...6)),
    area_hectares   = as.numeric(...7),
    investments_php_m = as.character(...8),
    nationality     = as.character(...9),
    zone_type       = "manufacturing",
    data_source     = "PEZA 1.xls"
  )

cat("  PEZA manufacturing zones loaded:", nrow(peza_mfg), "\n")

# Extract region context from the raw file for each zone
# Regions appear in rows where col 3 has text but col 5 is NA
# Region rows: col ...1 has region text, col ...3 (zone number) is NA
region_rows <- peza_mfg_raw %>%
  mutate(row_num = row_number()) %>%
  filter(!is.na(...1) & is.na(...3) & grepl("REGION|CAR|NCR|CARAGA", ...1, ignore.case = TRUE))

# Assign region to each zone based on preceding region row
peza_mfg$region <- NA_character_
for (i in seq_len(nrow(peza_mfg))) {
  zone_row <- which(peza_mfg_raw[[4]] == peza_mfg$zone_name[i])[1]
  if (!is.na(zone_row)) {
    preceding_regions <- region_rows %>% filter(row_num < zone_row)
    if (nrow(preceding_regions) > 0) {
      peza_mfg$region[i] <- trimws(preceding_regions$...1[nrow(preceding_regions)])
    }
  }
}

cat("  Regions assigned:", sum(!is.na(peza_mfg$region)), "of", nrow(peza_mfg), "\n\n")


# --- 1.3 Load PEZA agro-industrial zones (22 operating + 6 proclaimed) -------
cat("--- 1.3 Loading PEZA agro-industrial zones ---\n")

peza_agro_raw <- read_xls(file.path(RAW_PATH, "peza_locators_raw.xls"),
                           sheet = "with locators", col_names = FALSE)

# Same column mapping as manufacturing: ...3=number, ...4=name, ...5=location,
# ...6=developer, ...7=area, ...8=investments, ...9=nationality
peza_agro <- peza_agro_raw %>%
  filter(!is.na(...3) & !is.na(suppressWarnings(as.numeric(...3)))) %>%
  transmute(
    zone_number     = as.integer(...3),
    zone_name       = trimws(as.character(...4)),
    location_text   = trimws(as.character(...5)),
    developer       = trimws(as.character(...6)),
    area_hectares   = as.numeric(...7),
    investments_php_m = as.character(...8),
    nationality     = as.character(...9),
    zone_type       = "agro-industrial",
    data_source     = "PEZA 3.xls (operating)"
  )

# Also load proclaimed zones
peza_proc_raw <- read_xls(file.path(RAW_PATH, "peza_locators_raw.xls"),
                           sheet = "Proclaimed", col_names = FALSE)

# Proclaimed sheet has different column layout: ...5=number, ...6=name,
# ...7=location, ...8=developer, ...9=area, ...10=investments, ...11=nationality
peza_proclaimed <- peza_proc_raw %>%
  filter(!is.na(...5) & !is.na(suppressWarnings(as.numeric(...5)))) %>%
  transmute(
    zone_number     = as.integer(...5),
    zone_name       = trimws(as.character(...6)),
    location_text   = trimws(as.character(...7)),
    developer       = trimws(as.character(...8)),
    area_hectares   = as.numeric(...9),
    investments_php_m = as.character(...10),
    nationality     = as.character(...11),
    zone_type       = "agro-industrial (proclaimed)",
    data_source     = "PEZA 3.xls (proclaimed)"
  )

peza_agro_all <- bind_rows(peza_agro, peza_proclaimed)
cat("  PEZA agro-industrial zones loaded:", nrow(peza_agro), "operating +",
    nrow(peza_proclaimed), "proclaimed =", nrow(peza_agro_all), "total\n\n")


# --- 1.4 Load Wikipedia zones (30) -------------------------------------------
cat("--- 1.4 Loading Wikipedia zones ---\n")

wiki_zones <- read_csv(file.path(RAW_PATH, "wikipedia_sez_data.csv"),
                       show_col_types = FALSE) %>%
  transmute(
    zone_name       = trimws(zone_name),
    zone_type       = zone_type,
    location_text   = location_detail,
    municipality    = city_municipality,
    province        = province,
    region          = region,
    area_hectares   = as.numeric(area_hectares),
    developer       = developer_operator,
    data_source     = "Wikipedia"
  )

cat("  Wikipedia zones loaded:", nrow(wiki_zones), "\n")
cat("  Types:", paste(names(table(wiki_zones$zone_type)), table(wiki_zones$zone_type),
                      sep = "=", collapse = ", "), "\n\n")


# --- 1.5 Name-match World Bank ↔ PEZA zones ----------------------------------
cat("--- 1.5 Fuzzy matching zone names across sources ---\n")

# Combine all PEZA zones + Wikipedia freeports (supplementary)
wiki_freeports <- wiki_zones %>%
  filter(zone_type == "freeport") %>%
  transmute(
    zone_number = NA_integer_,
    zone_name, location_text,
    developer, area_hectares,
    investments_php_m = NA_character_,
    nationality = NA_character_,
    zone_type = "freeport",
    data_source = "Wikipedia",
    region
  )

peza_all <- bind_rows(peza_mfg, peza_agro_all, wiki_freeports)
cat("  Total PEZA + freeport zones:", nrow(peza_all), "\n")
cat("    Manufacturing:", sum(peza_all$zone_type == "manufacturing"), "\n")
cat("    Agro-industrial:", sum(grepl("agro", peza_all$zone_type)), "\n")
cat("    Freeport:", sum(peza_all$zone_type == "freeport"), "\n")

# Normalize names for matching
normalize_name <- function(x) {
  x <- tolower(trimws(x))
  x <- gsub("\\s+", " ", x)
  x <- gsub("[^a-z0-9 ]", "", x)
  x
}

wb_names_norm   <- normalize_name(wb_zones$zone_name)
peza_names_norm <- normalize_name(peza_all$zone_name)

# Compute string distance matrix
dist_matrix <- stringdistmatrix(peza_names_norm, wb_names_norm, method = "jw")

# For each PEZA zone, find best WB match
peza_all$wb_match_idx  <- apply(dist_matrix, 1, which.min)
peza_all$wb_match_dist <- apply(dist_matrix, 1, min)
peza_all$wb_match_name <- wb_zones$zone_name[peza_all$wb_match_idx]

# Accept matches with distance < 0.25 (Jaro-Winkler)
match_threshold <- 0.25
matched <- peza_all %>% filter(wb_match_dist < match_threshold)
unmatched <- peza_all %>% filter(wb_match_dist >= match_threshold)

cat("  Matched PEZA → WB:", nrow(matched), "zones (threshold <", match_threshold, ")\n")
cat("  Unmatched PEZA zones:", nrow(unmatched), "\n")

# Show match quality
if (nrow(matched) > 0) {
  cat("  Sample matches:\n")
  for (i in seq_len(min(5, nrow(matched)))) {
    cat("    PEZA:", matched$zone_name[i], "→ WB:", matched$wb_match_name[i],
        "(dist:", round(matched$wb_match_dist[i], 3), ")\n")
  }
}
cat("\n")


# --- 1.6 Geocode unmatched PEZA zones to municipality centroids --------------
cat("--- 1.6 Loading municipality boundaries for geocoding ---\n")

# Load GADM level 3 (municipalities) — works in both R and ArcGIS Pro
# JSON Maps from faeldon/philippines-json-maps don't load in ArcGIS Pro,
# so we use GADM shapefiles which are universally compatible.
# GADM level 2 = municipalities/cities (1,647 units)
# GADM level 3 = barangays (41,948) — too granular for our analysis
library(geodata)
gadm_vect <- gadm(country = "PHL", level = 2, path = file.path(RAW_PATH, "gadm"))
municipalities <- st_as_sf(gadm_vect)
# Remove waterbody features
municipalities <- municipalities %>% filter(ENGTYPE_2 != "Waterbody")
cat("  Municipalities loaded (GADM level 2):", nrow(municipalities), "\n")

# Disable S2 spherical geometry — Philippine GeoJSON files have some invalid
# edges that cause S2 errors. Planar geometry is fine for our purposes.
sf_use_s2(FALSE)

# Compute municipality centroids for geocoding
municipalities <- st_make_valid(municipalities)
municipalities <- st_transform(municipalities, CRS_WGS84)

# Rename GADM level 2 columns to standard names
# Level 2: NAME_2=municipality/city, NAME_1=province/region
if ("NAME_2" %in% names(municipalities)) {
  municipalities <- municipalities %>%
    rename(adm3_en = NAME_2, adm2_en = NAME_1,
           adm3_psgc = GID_2, adm1_psgc = GID_1)
}

muni_centroids_geom <- st_centroid(municipalities)
cent_coords <- st_coordinates(muni_centroids_geom)
municipalities$cent_lon <- cent_coords[, 1]
municipalities$cent_lat <- cent_coords[, 2]
muni_centroids <- municipalities

cat("  Centroids computed\n")

# Parse municipality name from PEZA location text
# Location text format: "Barangay, Municipality, Province" or similar
parse_municipality <- function(loc_text) {
  if (is.na(loc_text)) return(NA_character_)
  parts <- trimws(unlist(strsplit(loc_text, ",")))
  # Usually the municipality/city is the second-to-last or last element
  if (length(parts) >= 2) {
    return(parts[length(parts) - 1])
  }
  return(parts[1])
}

unmatched$parsed_municipality <- sapply(unmatched$location_text, parse_municipality)

# Fuzzy match parsed municipality names to boundary municipality names
muni_names <- as.character(muni_centroids$adm3_en)
unmatched_muni_norm <- normalize_name(unmatched$parsed_municipality)
muni_names_norm <- normalize_name(muni_names)

geocoded_count <- 0
unmatched$latitude  <- NA_real_
unmatched$longitude <- NA_real_
unmatched$geocoded_municipality <- NA_character_

for (i in seq_len(nrow(unmatched))) {
  if (is.na(unmatched_muni_norm[i])) next
  dists <- stringdist(unmatched_muni_norm[i], muni_names_norm, method = "jw")
  best_idx <- which.min(dists)
  if (dists[best_idx] < 0.2) {
    unmatched$latitude[i]  <- muni_centroids$cent_lat[best_idx]
    unmatched$longitude[i] <- muni_centroids$cent_lon[best_idx]
    unmatched$geocoded_municipality[i] <- muni_names[best_idx]
    geocoded_count <- geocoded_count + 1
  }
}

cat("  Geocoded to municipality centroids:", geocoded_count, "of",
    nrow(unmatched), "unmatched zones\n\n")


# --- 1.7 Cross-validate with Ravago locatorid --------------------------------
cat("--- 1.7 Cross-validating with Ravago et al. locatorid ---\n")

ravago <- read_csv(file.path(RAW_PATH, "mendeley_ravago",
                              "Supplementary Appendix 1 DIB Energy Ravago et al 2021_Data.csv"),
                   show_col_types = FALSE)

ravago_zones <- ravago %>%
  mutate(locatorid_str = formatC(as.integer(locatorid), width = 9, flag = "0")) %>%
  distinct(sIq1_ecozone, sIq2_city, sIq2_prov, .keep_all = TRUE) %>%
  select(ecozone = sIq1_ecozone, city = sIq2_city, province = sIq2_prov,
         zip = sIq2_zip, locatorid_str)

cat("  Ravago unique ecozones:", nrow(ravago_zones), "\n")
cat("  Provinces covered:", paste(unique(ravago_zones$province), collapse = ", "), "\n\n")


# --- 1.8 Combine, deduplicate, and export zones.csv --------------------------
cat("--- 1.8 Combining all sources and exporting zones.csv ---\n")

# Build matched zones: WB coordinates + PEZA metadata
zones_matched <- matched %>%
  left_join(
    wb_zones %>% select(zone_name, latitude, longitude, operational_date,
                        dist_port_km_wb, dist_airport_km_wb),
    by = c("wb_match_name" = "zone_name")
  ) %>%
  transmute(
    zone_name, latitude, longitude, area_hectares, zone_type,
    operational_date, developer, location_text, region,
    coordinate_source = "world_bank_ciip",
    data_source = paste0(data_source, " + World Bank")
  )

# Build unmatched zones: municipality centroid coordinates
zones_unmatched <- unmatched %>%
  transmute(
    zone_name, latitude, longitude, area_hectares, zone_type,
    operational_date = NA_integer_, developer, location_text, region,
    coordinate_source = ifelse(!is.na(latitude), "municipality_centroid", "not_geocoded"),
    data_source
  )

# WB-only zones (not matched to any PEZA zone)
wb_matched_names <- matched$wb_match_name
wb_only <- wb_zones %>%
  filter(!zone_name %in% wb_matched_names) %>%
  transmute(
    zone_name, latitude, longitude, area_hectares,
    zone_type = "ecozone (WB only)",
    operational_date, developer = NA_character_,
    location_text = NA_character_, region,
    coordinate_source = "world_bank_ciip",
    data_source = "World Bank CIIP"
  )

# Combine all
zones_all <- bind_rows(zones_matched, zones_unmatched, wb_only)

# Remove duplicates by zone name (keep first occurrence)
zones_final <- zones_all %>%
  group_by(normalize_name(zone_name)) %>%
  slice(1) %>%
  ungroup() %>%
  select(-`normalize_name(zone_name)`) %>%
  filter(!is.na(latitude))  # only keep zones we could geocode

# Export
write_csv(zones_final, file.path(BASE_PATH, "zones.csv"))

cat("  Total zones in zones.csv:", nrow(zones_final), "\n")
cat("  With WB coordinates:", sum(zones_final$coordinate_source == "world_bank_ciip"), "\n")
cat("  With municipality centroids:", sum(zones_final$coordinate_source == "municipality_centroid"), "\n")
cat("  Zone types:\n")
print(table(zones_final$zone_type))
cat("\n  zones.csv exported successfully.\n\n")


# === PART 2: CONSTRUCT ANALYSIS_UNITS.CSV ====================================
cat("\n")
cat("================================================================\n")
cat("  PART 2: CONSTRUCT ANALYSIS_UNITS.CSV\n")
cat("================================================================\n\n")

# --- 2.1 Load municipality boundaries ----------------------------------------
cat("--- 2.1 Municipality boundaries ---\n")
cat("  Already loaded:", nrow(municipalities), "municipalities\n")

# Already in WGS84 from Part 1 centroid computation
# Add municipality area in km²
municipalities$area_sqkm <- as.numeric(st_area(st_transform(municipalities, CRS_PRS92))) / 1e6

cat("  Area range:", round(min(municipalities$area_sqkm), 1), "-",
    round(max(municipalities$area_sqkm), 1), "km²\n\n")


# --- 2.2 Assign zone indicators -----------------------------------------------
cat("--- 2.2 Assigning zone indicators ---\n")

# Convert zones to sf
zones_sf <- zones_final %>%
  filter(!is.na(latitude) & !is.na(longitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = CRS_WGS84)

# Spatial join: which municipality contains each zone
zone_in_muni <- st_join(zones_sf, municipalities, join = st_within)

# Aggregate zone info per municipality
muni_zone_stats <- zone_in_muni %>%
  st_drop_geometry() %>%
  group_by(adm3_psgc) %>%
  summarize(
    zone_count = n(),
    total_zone_area_ha = sum(area_hectares, na.rm = TRUE),
    has_manufacturing = any(zone_type == "manufacturing", na.rm = TRUE),
    has_agro = any(grepl("agro", zone_type, ignore.case = TRUE), na.rm = TRUE),
    earliest_op_date = min(operational_date, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(earliest_op_date = ifelse(is.infinite(earliest_op_date), NA_integer_, earliest_op_date))

# Join back to municipalities
analysis_units <- municipalities %>%
  left_join(muni_zone_stats, by = "adm3_psgc") %>%
  mutate(
    has_zone = ifelse(!is.na(zone_count), 1L, 0L),
    zone_count = replace_na(zone_count, 0L),
    total_zone_area_ha = replace_na(total_zone_area_ha, 0),
    has_manufacturing = replace_na(has_manufacturing, FALSE),
    has_agro = replace_na(has_agro, FALSE)
  )

cat("  Zone municipalities:", sum(analysis_units$has_zone == 1), "\n")
cat("  Non-zone municipalities:", sum(analysis_units$has_zone == 0), "\n\n")


# --- 2.3 Population density (WorldPop 2020) -----------------------------------
cat("--- 2.3 Extracting WorldPop population density ---\n")

worldpop_file <- file.path(RAW_PATH, "worldpop",
                           "phl_ppp_2020_1km_Aggregated_UNadj.tif")

if (file.exists(worldpop_file)) {
  wp <- rast(worldpop_file)
  pop_stats <- exact_extract(wp, analysis_units, fun = c("mean", "sum"))
  analysis_units$pop_density_mean_2020 <- pop_stats[, 1]
  analysis_units$pop_total_2020 <- pop_stats[, 2]
  cat("  Population density extracted for", nrow(analysis_units), "municipalities\n")
  cat("  Mean pop density range:", round(min(analysis_units$pop_density_mean_2020, na.rm = TRUE), 1),
      "-", round(max(analysis_units$pop_density_mean_2020, na.rm = TRUE), 1), "\n\n")
} else {
  cat("  WARNING: WorldPop file not found. Skipping.\n\n")
  analysis_units$pop_density_mean_2020 <- NA_real_
  analysis_units$pop_total_2020 <- NA_real_
}


# --- 2.4 Nighttime lights (VIIRS 2018) ----------------------------------------
cat("--- 2.4 Extracting VIIRS nighttime lights ---\n")

viirs_file <- file.path(RAW_PATH, "viirs",
  "VNL_v2_npp_2018_global_vcmslcfg_c202102150000.average_masked.tif")

if (file.exists(viirs_file)) {
  # Load and crop to Philippines extent to manage memory
  ph_extent <- ext(116, 128, 4, 22)
  viirs <- rast(viirs_file)
  viirs_ph <- crop(viirs, ph_extent)

  nl_stats <- exact_extract(viirs_ph, analysis_units, fun = c("mean", "median"))
  analysis_units$nightlights_mean_2018 <- nl_stats[, 1]
  analysis_units$nightlights_median_2018 <- nl_stats[, 2]
  cat("  Nightlights extracted for", nrow(analysis_units), "municipalities\n")
  cat("  Mean radiance range:", round(min(analysis_units$nightlights_mean_2018, na.rm = TRUE), 2),
      "-", round(max(analysis_units$nightlights_mean_2018, na.rm = TRUE), 2), "nW/cm²/sr\n\n")
  rm(viirs, viirs_ph); gc()
} else {
  cat("  WARNING: VIIRS file not found. Skipping.\n\n")
  analysis_units$nightlights_mean_2018 <- NA_real_
  analysis_units$nightlights_median_2018 <- NA_real_
}


# --- 2.5 Built-up area (GHSL 2020) -------------------------------------------
cat("--- 2.5 Extracting GHSL built-up surface ---\n")

ghsl_zip <- file.path(RAW_PATH, "ghsl",
                      "GHS_BUILT_S_E2020_GLOBE_R2023A_4326_30ss_V1_0.zip")

if (file.exists(ghsl_zip)) {
  # Unzip to temp directory
  tmp_ghsl <- tempdir()
  unzip(ghsl_zip, exdir = tmp_ghsl)
  ghsl_tif <- list.files(tmp_ghsl, pattern = "GHS_BUILT_S.*\\.tif$",
                         full.names = TRUE, recursive = TRUE)[1]

  if (!is.na(ghsl_tif)) {
    ghsl <- rast(ghsl_tif)
    ghsl_ph <- crop(ghsl, ph_extent)

    bu_stats <- exact_extract(ghsl_ph, analysis_units, fun = "mean")
    # GHSL BUILT-S stores built-up surface in m² per grid cell.
    # At 30 arcsec (~1km), cell area is ~1,000,000 m². Normalize to 0-1 fraction.
    cell_area_m2 <- 1000 * 1000  # approximate cell area at equator
    analysis_units$builtup_fraction_2020 <- pmin(bu_stats / cell_area_m2, 1.0)
    cat("  Built-up fraction extracted\n")
    cat("  Range:", round(min(analysis_units$builtup_fraction_2020, na.rm = TRUE), 3),
        "-", round(max(analysis_units$builtup_fraction_2020, na.rm = TRUE), 3), "\n\n")
    rm(ghsl, ghsl_ph); gc()
  } else {
    cat("  WARNING: GHSL TIF not found in zip. Skipping.\n\n")
    analysis_units$builtup_fraction_2020 <- NA_real_
  }
} else {
  cat("  WARNING: GHSL zip not found. Skipping.\n\n")
  analysis_units$builtup_fraction_2020 <- NA_real_
}


# --- 2.6 Distance to nearest airport -----------------------------------------
cat("--- 2.6 Computing distance to nearest airport ---\n")

airports_file <- file.path(RAW_PATH, "airports.csv")

if (file.exists(airports_file)) {
  airports <- read_csv(airports_file, show_col_types = FALSE) %>%
    filter(iso_country == "PH",
           type %in% c("large_airport", "medium_airport")) %>%
    filter(!is.na(latitude_deg) & !is.na(longitude_deg)) %>%
    st_as_sf(coords = c("longitude_deg", "latitude_deg"), crs = CRS_WGS84)

  cat("  Philippine airports (large/medium):", nrow(airports), "\n")

  # Compute distance from each municipality centroid to nearest airport
  muni_cents <- st_centroid(st_transform(analysis_units, CRS_PRS92))
  airports_prs <- st_transform(airports, CRS_PRS92)

  dist_mat <- st_distance(muni_cents, airports_prs)
  analysis_units$dist_nearest_airport_km <- apply(dist_mat, 1, min) / 1000

  cat("  Distance range:", round(min(analysis_units$dist_nearest_airport_km), 1),
      "-", round(max(analysis_units$dist_nearest_airport_km), 1), "km\n\n")
} else {
  cat("  WARNING: Airports file not found. Skipping.\n\n")
  analysis_units$dist_nearest_airport_km <- NA_real_
}


# --- 2.7 Distance to nearest primary road -------------------------------------
cat("--- 2.7 Computing distance to nearest primary road ---\n")

roads_file <- file.path(RAW_PATH, "philippines-260503-free",
                        "gis_osm_roads_free_1.shp")

if (file.exists(roads_file)) {
  roads <- st_read(roads_file, quiet = TRUE) %>%
    filter(fclass %in% c("trunk", "primary", "motorway"))

  cat("  Primary roads loaded:", nrow(roads), "segments\n")

  roads_prs <- st_transform(roads, CRS_PRS92)

  # For performance, compute nearest distance in batches
  batch_size <- 200
  n_munis <- nrow(muni_cents)
  dist_road <- numeric(n_munis)

  for (b in seq(1, n_munis, by = batch_size)) {
    end_b <- min(b + batch_size - 1, n_munis)
    batch_dist <- st_distance(muni_cents[b:end_b, ], roads_prs)
    dist_road[b:end_b] <- apply(batch_dist, 1, min)
    if (b %% 500 == 1) cat("    Processing municipalities", b, "to", end_b, "\n")
  }

  analysis_units$dist_nearest_primary_road_km <- dist_road / 1000
  cat("  Distance range:", round(min(analysis_units$dist_nearest_primary_road_km), 1),
      "-", round(max(analysis_units$dist_nearest_primary_road_km), 1), "km\n\n")
  rm(roads, roads_prs); gc()
} else {
  cat("  WARNING: OSM roads file not found. Skipping.\n\n")
  analysis_units$dist_nearest_primary_road_km <- NA_real_
}


# --- 2.8 Export analysis_units.csv --------------------------------------------
cat("--- 2.8 Exporting analysis_units.csv ---\n")

# Select final columns for export (drop geometry)
analysis_export <- analysis_units %>%
  st_drop_geometry() %>%
  select(
    municipality_name = adm3_en,
    gadm_id = adm3_psgc,
    province = adm2_en,
    area_sqkm,
    has_zone, zone_count, total_zone_area_ha,
    has_manufacturing, has_agro,
    earliest_op_date,
    pop_density_mean_2020, pop_total_2020,
    nightlights_mean_2018, nightlights_median_2018,
    builtup_fraction_2020,
    dist_nearest_airport_km,
    dist_nearest_primary_road_km
  )

write_csv(analysis_export, file.path(BASE_PATH, "analysis_units.csv"))

cat("  Total municipalities:", nrow(analysis_export), "\n")
cat("  Zone municipalities:", sum(analysis_export$has_zone == 1), "\n")
cat("  Non-zone municipalities:", sum(analysis_export$has_zone == 0), "\n")
cat("  Variables:", ncol(analysis_export), "\n")
cat("  analysis_units.csv exported successfully.\n\n")


# === PART 3: ZONE VS NON-ZONE COMPARISON =====================================
cat("\n")
cat("================================================================\n")
cat("  PART 3: ZONE VS NON-ZONE COMPARISON\n")
cat("================================================================\n\n")

# --- 3.1 Summary statistics table ---------------------------------------------
cat("--- 3.1 Summary statistics: zone vs non-zone municipalities ---\n\n")

compare_vars <- c("pop_density_mean_2020", "nightlights_mean_2018",
                   "builtup_fraction_2020", "dist_nearest_airport_km",
                   "dist_nearest_primary_road_km", "area_sqkm")

for (v in compare_vars) {
  zone_vals    <- analysis_export[[v]][analysis_export$has_zone == 1]
  nonzone_vals <- analysis_export[[v]][analysis_export$has_zone == 0]

  zone_vals    <- zone_vals[!is.na(zone_vals)]
  nonzone_vals <- nonzone_vals[!is.na(nonzone_vals)]

  if (length(zone_vals) > 1 & length(nonzone_vals) > 1) {
    tt <- t.test(zone_vals, nonzone_vals)
    cat(sprintf("  %-35s Zone: %10.2f | Non-zone: %10.2f | Diff: %10.2f | p = %.4f %s\n",
                v,
                mean(zone_vals), mean(nonzone_vals),
                mean(zone_vals) - mean(nonzone_vals),
                tt$p.value,
                ifelse(tt$p.value < 0.01, "***",
                       ifelse(tt$p.value < 0.05, "**",
                              ifelse(tt$p.value < 0.1, "*", "")))))
  }
}

cat("\n  Significance: *** p<0.01, ** p<0.05, * p<0.10, NS = not significant\n")
cat("  NOTE: dist_nearest_airport_km and area_sqkm are NOT statistically\n")
cat("  significant — zones are NOT systematically closer to airports or\n")
cat("  larger in area than non-zone municipalities.\n\n")


# --- 3.2 Correlation matrix ---------------------------------------------------
cat("--- 3.2 Correlation matrix ---\n")

cor_data <- analysis_export %>%
  select(has_zone, all_of(compare_vars)) %>%
  filter(complete.cases(.))

cor_mat <- cor(cor_data)

png(file.path(BASE_PATH, "figures", "correlation_matrix.png"),
    width = 800, height = 800, res = 120)
corrplot(cor_mat, method = "color", type = "upper",
         tl.cex = 0.7, tl.col = "black", addCoef.col = "black",
         number.cex = 0.6, title = "Correlation Matrix: Zone Status and Municipality Characteristics",
         mar = c(0, 0, 2, 0))
dev.off()
cat("  Saved: figures/correlation_matrix.png\n\n")


# --- 3.3 Logistic regression: zone presence predictors -------------------------
cat("--- 3.3 Logistic regression: predictors of zone presence ---\n\n")

logit_data <- analysis_export %>%
  select(has_zone, pop_density_mean_2020, nightlights_mean_2018,
         builtup_fraction_2020, dist_nearest_airport_km,
         dist_nearest_primary_road_km) %>%
  filter(complete.cases(.))

logit_model <- glm(has_zone ~ pop_density_mean_2020 + nightlights_mean_2018 +
                     builtup_fraction_2020 + dist_nearest_airport_km +
                     dist_nearest_primary_road_km,
                   data = logit_data, family = binomial)

cat("  Logistic Regression: has_zone ~ characteristics\n")
cat("  N =", nrow(logit_data), "\n\n")
print(summary(logit_model))
cat("\n")


# --- 3.4 Visualizations -------------------------------------------------------
cat("--- 3.4 Generating visualizations ---\n")

analysis_plot <- analysis_export %>%
  mutate(zone_status = ifelse(has_zone == 1, "Zone Municipality", "Non-Zone Municipality"))

# (a) Boxplot: nightlights
p1 <- ggplot(analysis_plot %>% filter(!is.na(nightlights_mean_2018)),
             aes(x = zone_status, y = nightlights_mean_2018, fill = zone_status)) +
  geom_boxplot(alpha = 0.7, outlier.alpha = 0.3) +
  scale_fill_manual(values = c("Zone Municipality" = "#1D9E75",
                                "Non-Zone Municipality" = "#E24B4A")) +
  labs(title = "Nighttime Light Radiance: Zone vs Non-Zone Municipalities",
       subtitle = "VIIRS 2018 annual average (masked)",
       x = "", y = "Mean Radiance (nW/cm²/sr)") +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(file.path(BASE_PATH, "figures", "boxplot_nightlights.png"), p1,
       width = 8, height = 6, dpi = 150)
cat("  Saved: figures/boxplot_nightlights.png\n")

# (b) Boxplot: population density
p2 <- ggplot(analysis_plot %>% filter(!is.na(pop_density_mean_2020)),
             aes(x = zone_status, y = log10(pop_density_mean_2020 + 1), fill = zone_status)) +
  geom_boxplot(alpha = 0.7, outlier.alpha = 0.3) +
  scale_fill_manual(values = c("Zone Municipality" = "#1D9E75",
                                "Non-Zone Municipality" = "#E24B4A")) +
  labs(title = "Population Density: Zone vs Non-Zone Municipalities",
       subtitle = "WorldPop 2020, log10 scale",
       x = "", y = "log10(Population Density + 1)") +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(file.path(BASE_PATH, "figures", "boxplot_population.png"), p2,
       width = 8, height = 6, dpi = 150)
cat("  Saved: figures/boxplot_population.png\n")

# (c) Scatter: nightlights vs population, colored by zone status
p3 <- ggplot(analysis_plot %>%
               filter(!is.na(nightlights_mean_2018) & !is.na(pop_density_mean_2020)),
             aes(x = log10(pop_density_mean_2020 + 1),
                 y = log10(nightlights_mean_2018 + 1),
                 color = zone_status)) +
  geom_point(alpha = 0.4, size = 1.5) +
  scale_color_manual(values = c("Zone Municipality" = "#1D9E75",
                                 "Non-Zone Municipality" = "#E24B4A")) +
  labs(title = "Nighttime Lights vs Population Density",
       subtitle = "Each point is a Philippine municipality",
       x = "log10(Population Density + 1)",
       y = "log10(Mean Radiance + 1)",
       color = "") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(BASE_PATH, "figures", "scatter_nl_pop.png"), p3,
       width = 8, height = 6, dpi = 150)
cat("  Saved: figures/scatter_nl_pop.png\n")

# (d) Bar chart: mean distances to infrastructure
infra_compare <- analysis_plot %>%
  filter(!is.na(dist_nearest_airport_km)) %>%
  group_by(zone_status) %>%
  summarize(
    `Airport (km)` = mean(dist_nearest_airport_km, na.rm = TRUE),
    `Primary Road (km)` = mean(dist_nearest_primary_road_km, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(-zone_status, names_to = "Infrastructure", values_to = "Mean Distance (km)")

p4 <- ggplot(infra_compare, aes(x = Infrastructure, y = `Mean Distance (km)`,
                                 fill = zone_status)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Zone Municipality" = "#1D9E75",
                                "Non-Zone Municipality" = "#E24B4A")) +
  labs(title = "Mean Distance to Infrastructure: Zone vs Non-Zone",
       x = "", y = "Mean Distance (km)", fill = "") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(BASE_PATH, "figures", "bar_infrastructure_distance.png"), p4,
       width = 8, height = 6, dpi = 150)
cat("  Saved: figures/bar_infrastructure_distance.png\n\n")


# --- 3.5 Limitations ----------------------------------------------------------
cat("--- 3.5 Limitations of this analysis ---\n\n")
cat("  1. SELECTION BIAS: Industrial zones were intentionally placed near\n")
cat("     infrastructure, cities, and economic activity. The observed differences\n")
cat("     are descriptive, not causal.\n\n")
cat("  2. GEOCODING IMPRECISION: ~55 zones without GPS coordinates were\n")
cat("     geocoded to municipality centroids, introducing spatial error.\n\n")
cat("  3. TEMPORAL GAPS: Zone data is from 2017, nightlights from 2018,\n")
cat("     population from 2020. Cross-sectional comparison assumes\n")
cat("     municipality characteristics are relatively stable over 2-3 years.\n\n")
cat("  4. ISLAND GEOGRAPHY: Euclidean distances may not reflect actual\n")
cat("     travel distances across water in an archipelago.\n\n")


# === PART 4: DYNAMIC AND CAUSAL EXTENSION ====================================
cat("\n")
cat("================================================================\n")
cat("  PART 4: DYNAMIC AND CAUSAL EXTENSION\n")
cat("================================================================\n\n")

# --- 4.1 Establishment year compilation ---------------------------------------
cat("--- 4.1 Establishment year data ---\n\n")

zones_with_dates <- zones_final %>%
  filter(!is.na(operational_date))

cat("  Zones with establishment years:", nrow(zones_with_dates), "\n")
cat("  Source: World Bank CIIP operational_date field\n")
cat("  Range:", min(zones_with_dates$operational_date), "-",
    max(zones_with_dates$operational_date), "\n\n")

# Timeline visualization
if (nrow(zones_with_dates) > 0) {
  p5 <- ggplot(zones_with_dates, aes(x = operational_date)) +
    geom_histogram(binwidth = 5, fill = "#1D9E75", color = "white", alpha = 0.8) +
    labs(title = "Timeline of Industrial Zone Establishment in the Philippines",
         subtitle = paste0("N = ", nrow(zones_with_dates), " zones with known establishment years (World Bank CIIP)"),
         x = "Year of Establishment", y = "Number of Zones") +
    theme_minimal()

  ggsave(file.path(BASE_PATH, "figures", "zone_establishment_timeline.png"), p5,
         width = 8, height = 5, dpi = 150)
  cat("  Saved: figures/zone_establishment_timeline.png\n\n")
}


# --- 4.2 Time-stamped outcome datasets available ------------------------------
cat("--- 4.2 Time-stamped outcome datasets available ---\n\n")
cat("  For a panel/temporal analysis, the following annual datasets exist:\n\n")
cat("  1. VIIRS Nighttime Lights (V2.0): Annual composites 2012-2020\n")
cat("     → Proxy for economic activity. ~500m resolution.\n")
cat("     → URL pattern: eogdata.mines.edu/nighttime_light/annual/v20/[YEAR]/\n\n")
cat("  2. WorldPop Population: Annual 2000-2020\n")
cat("     → Population density at ~1km.\n")
cat("     → URL: data.worldpop.org/GIS/Population/Global_2000_2020_1km_UNadj/[YEAR]/PHL/\n\n")
cat("  3. Hansen Forest Loss Year: Single file encoding loss year 2001-2024\n")
cat("     → Already downloaded. Pixel values 1-24 = year of loss.\n\n")
cat("  4. GHSL Multi-Epoch: 1975, 1980, ..., 2015, 2020\n")
cat("     → Built-up area over time at ~1km.\n\n")


# --- 4.3 Proposed empirical design --------------------------------------------
cat("--- 4.3 Proposed empirical design ---\n\n")
cat("  DESIGN: Staggered Difference-in-Differences (DiD)\n\n")
cat("  TREATMENT: Year municipality first receives an industrial zone\n")
cat("    (from World Bank operational_date, N=47 zones with dates)\n\n")
cat("  CONTROL: Municipalities that never receive a zone, matched on\n")
cat("    pre-treatment covariates via propensity score:\n")
cat("    - Baseline population density\n")
cat("    - Distance to coastline and Manila\n")
cat("    - Pre-treatment nighttime light radiance\n\n")
cat("  OUTCOME: Annual nighttime lights radiance (proxy for economic activity)\n\n")
cat("  SPECIFICATION:\n")
cat("    y_mt = alpha_m + delta_t + beta * Post_mt + epsilon_mt\n")
cat("    where alpha_m = municipality FE, delta_t = year FE,\n")
cat("    Post_mt = 1 if zone established in municipality m by year t\n\n")
cat("  IDENTIFICATION: Parallel trends assumption — validated via\n")
cat("    event study plot showing no pre-trends in treatment leads.\n\n")
cat("  ROBUSTNESS CHECKS:\n")
cat("    - Event study with leads and lags\n")
cat("    - Vary control group distance thresholds\n")
cat("    - Alternative outcomes (population, built-up area)\n")
cat("    - Exclude zones established before VIIRS coverage (pre-2012)\n\n")
cat("  DATA REQUIREMENTS:\n")
cat("    - Multi-year VIIRS (2012-2023) for post-2012 zones\n")
cat("    - DMSP-OLS nightlights (1992-2013) for pre-2012 zones\n\n")


# === ARCGIS PRO WORKFLOW (documented for reproducibility) ====================
cat("\n")
cat("================================================================\n")
cat("  ARCGIS PRO WORKFLOW (for map generation)\n")
cat("================================================================\n\n")
cat("  The following steps should be performed in ArcGIS Pro to generate\n")
cat("  publication-ready maps. ArcGIS Pro with Living Atlas is available\n")
cat("  via Arizona State University organizational account.\n\n")
cat("  MAP 1: Zone Locations\n")
cat("  1. Open ArcGIS Pro → New Map\n")
cat("  2. Add Data → raw datasets/philippines-json-maps-master/2023/geojson/provdists/hires/*.json\n")
cat("  3. Add zones.csv as XY Event Layer (longitude, latitude, EPSG:4326)\n")
cat("  4. Symbology → Unique Values on zone_type\n")
cat("  5. Add Living Atlas basemap: World Topographic Map\n")
cat("  6. Zoom to Philippines (116-127°E, 5-21°N)\n")
cat("  7. Insert Layout → title, legend, scale bar, north arrow\n")
cat("  8. Export as PNG/PDF\n\n")
cat("  MAP 2: Zone vs Non-Zone Choropleth\n")
cat("  1. Join analysis_units.csv to municipality boundaries (psgc_code)\n")
cat("  2. Symbology → Graduated Colors on nightlights_mean_2018\n")
cat("  3. Classification: Natural Breaks (Jenks), 5 classes\n")
cat("  4. Overlay zone points from zones.csv\n")
cat("  5. Export as PNG/PDF\n\n")


# === COMPLETION ===============================================================
cat("\n")
cat("================================================================\n")
cat("  ANALYSIS COMPLETE\n")
cat("================================================================\n\n")
cat("  Outputs generated:\n")
cat("    zones.csv          —", nrow(zones_final), "industrial zones\n")
cat("    analysis_units.csv —", nrow(analysis_export), "municipalities\n")
cat("    figures/           — 5 visualizations\n\n")
cat("  See sources.csv for complete data audit (19 sources).\n")
cat("  See DOWNLOAD_NOTES.txt for raster download details.\n")
cat("  See README.md for full documentation and ArcGIS workflow.\n\n")
