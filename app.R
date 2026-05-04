# ─────────────────────────────────────────────────────────────────────────────
# Philippines Industrial Zones Explorer — Shiny Dashboard
# ─────────────────────────────────────────────────────────────────────────────
#
# DATA CONTRACT
# This app reads pre-processed CSV files from analysis.R:
#   zones.csv          — zone_name, latitude, longitude, zone_type, area_hectares, ...
#   analysis_units.csv — municipality_name, has_zone, pop_density_mean_2020, ...
#   sources.csv        — source_name, link, type, raw_download_available, ...
#
# Run: shiny::runApp("app.R")
# Deploy: rsconnect::deployApp(".")
# ─────────────────────────────────────────────────────────────────────────────

library(shiny)
library(leaflet)
library(DT)
library(plotly)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

# ── DATA LOAD ────────────────────────────────────────────────────────────────

zones <- read_csv("zones.csv", show_col_types = FALSE)
analysis <- read_csv("analysis_units.csv", show_col_types = FALSE)
sources <- read_csv("sources.csv", show_col_types = FALSE)

# ── CONSTANTS ────────────────────────────────────────────────────────────────

ZONE_COLORS <- list(
  "manufacturing"                 = "#2166AC",
  "agro-industrial"               = "#1B7837",
  "agro-industrial (proclaimed)"  = "#7FBC41",
  "ecozone (WB only)"            = "#F4A582",
  "freeport"                      = "#E08214"
)

COMPARE_VARS <- c(
  "pop_density_mean_2020", "nightlights_mean_2018",
  "builtup_fraction_2020", "dist_nearest_airport_km",
  "dist_nearest_primary_road_km", "area_sqkm"
)

VAR_LABELS <- c(
  pop_density_mean_2020       = "Population Density (WorldPop 2020)",
  nightlights_mean_2018       = "Night Lights (VIIRS 2018, nW/cm²/sr)",
  builtup_fraction_2020       = "Built-up Fraction (GHSL 2020)",
  dist_nearest_airport_km     = "Distance to Airport (km)",
  dist_nearest_primary_road_km = "Distance to Primary Road (km)",
  area_sqkm                   = "Municipality Area (km²)"
)

# ── UI ───────────────────────────────────────────────────────────────────────

ui <- navbarPage(
  title = "Philippines Industrial Zones Explorer",
  theme = NULL,

  # Tab 1: Zone Map
  tabPanel("Zone Map",
    div(style = "padding: 10px;",
      h4("Industrial Zone Locations in the Philippines"),
      p("93 zones from PEZA and World Bank. Click a marker for details."),
      leafletOutput("zone_map", height = "600px"),
      br(),
      DTOutput("zone_table")
    )
  ),

  # Tab 2: Municipality Comparison
  tabPanel("Municipality Comparison",
    div(style = "padding: 10px;",
      fluidRow(
        column(4,
          selectInput("compare_var", "Select Variable:",
                      choices = setNames(COMPARE_VARS, VAR_LABELS[COMPARE_VARS]),
                      selected = "nightlights_mean_2018"),
          hr(),
          h5("Summary"),
          verbatimTextOutput("compare_summary")
        ),
        column(8,
          plotlyOutput("compare_boxplot", height = "350px"),
          plotlyOutput("compare_density", height = "350px")
        )
      )
    )
  ),

  # Tab 3: Analysis
  tabPanel("Analysis",
    div(style = "padding: 10px;",
      fluidRow(
        column(6,
          h4("Zone vs Non-Zone: Scatter Plot"),
          selectInput("scatter_x", "X Axis:",
                      choices = setNames(COMPARE_VARS, VAR_LABELS[COMPARE_VARS]),
                      selected = "pop_density_mean_2020"),
          selectInput("scatter_y", "Y Axis:",
                      choices = setNames(COMPARE_VARS, VAR_LABELS[COMPARE_VARS]),
                      selected = "nightlights_mean_2018"),
          plotlyOutput("scatter_plot", height = "450px")
        ),
        column(6,
          h4("Correlation Matrix"),
          plotOutput("corr_plot", height = "450px"),
          br(),
          h5("T-test Results: Zone vs Non-Zone"),
          DTOutput("ttest_table")
        )
      )
    )
  ),

  # Tab 4: Timeline
  tabPanel("Temporal Trends",
    div(style = "padding: 10px;",
      h4("Zone Establishment Timeline"),
      p("47 zones with known establishment years from World Bank CIIP (1974-2014)."),
      plotlyOutput("timeline_plot", height = "350px"),
      br(),
      h4("Cumulative Zone Count Over Time"),
      plotlyOutput("cumulative_plot", height = "350px"),
      br(),
      h4("Proposed Empirical Design"),
      wellPanel(
        p(strong("Design:"), "Staggered Difference-in-Differences"),
        p(strong("Treatment:"), "Year municipality first receives an industrial zone"),
        p(strong("Control:"), "Municipalities that never receive a zone, matched on pre-treatment covariates"),
        p(strong("Outcome:"), "Annual nighttime lights radiance (proxy for economic activity)"),
        p(strong("Specification:"), "y_mt = α_m + δ_t + β × Post_mt + ε_mt"),
        p(strong("Key Assumption:"), "Parallel trends in pre-treatment period")
      )
    )
  ),

  # Tab 5: Data Sources
  tabPanel("Data Sources",
    div(style = "padding: 10px;",
      h4("Source Audit Table (19 Sources)"),
      p("Complete documentation of all data sources used or seriously considered."),
      DTOutput("sources_table")
    )
  )
)

# ── SERVER ───────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # Reactive: analysis with zone label
  analysis_labeled <- reactive({
    analysis %>%
      mutate(zone_status = ifelse(has_zone == 1, "Zone", "Non-Zone"))
  })

  # ── Tab 1: Zone Map ──────────────────────────────────────────────────────

  output$zone_map <- renderLeaflet({
    zones_valid <- zones %>% filter(!is.na(latitude) & !is.na(longitude))

    pal <- colorFactor(
      palette = unname(unlist(ZONE_COLORS)),
      domain = names(ZONE_COLORS),
      na.color = "#999999"
    )

    leaflet(zones_valid) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = 121.5, lat = 12.5, zoom = 6) %>%
      addCircleMarkers(
        lng = ~longitude, lat = ~latitude,
        radius = ~pmin(sqrt(area_hectares) / 3, 15),
        color = ~pal(zone_type),
        fillOpacity = 0.7, stroke = TRUE, weight = 1,
        popup = ~paste0(
          "<b>", zone_name, "</b><br>",
          "Type: ", zone_type, "<br>",
          "Area: ", round(area_hectares, 1), " ha<br>",
          "Source: ", coordinate_source, "<br>",
          ifelse(!is.na(operational_date),
                 paste0("Est: ", operational_date), "")
        )
      ) %>%
      addLegend("bottomright", pal = pal, values = ~zone_type,
                title = "Zone Type", opacity = 0.8)
  })

  output$zone_table <- renderDT({
    zones %>%
      select(zone_name, zone_type, area_hectares, operational_date,
             coordinate_source, data_source) %>%
      datatable(options = list(pageLength = 10, scrollX = TRUE),
                filter = "top", rownames = FALSE)
  })

  # ── Tab 2: Municipality Comparison ───────────────────────────────────────

  output$compare_boxplot <- renderPlotly({
    df <- analysis_labeled()
    var <- input$compare_var
    lab <- VAR_LABELS[var]

    p <- ggplot(df %>% filter(!is.na(.data[[var]])),
                aes(x = zone_status, y = .data[[var]], fill = zone_status)) +
      geom_boxplot(alpha = 0.7, outlier.alpha = 0.3) +
      scale_fill_manual(values = c("Zone" = "#1D9E75", "Non-Zone" = "#E24B4A")) +
      labs(title = paste(lab, "— Zone vs Non-Zone"), x = "", y = lab) +
      theme_minimal() +
      theme(legend.position = "none")

    ggplotly(p)
  })

  output$compare_density <- renderPlotly({
    df <- analysis_labeled()
    var <- input$compare_var
    lab <- VAR_LABELS[var]

    p <- ggplot(df %>% filter(!is.na(.data[[var]])),
                aes(x = .data[[var]], fill = zone_status)) +
      geom_density(alpha = 0.5) +
      scale_fill_manual(values = c("Zone" = "#1D9E75", "Non-Zone" = "#E24B4A")) +
      labs(title = paste("Distribution:", lab), x = lab, y = "Density", fill = "") +
      theme_minimal()

    ggplotly(p)
  })

  output$compare_summary <- renderPrint({
    df <- analysis_labeled()
    var <- input$compare_var

    zone_vals <- df[[var]][df$has_zone == 1]
    nonzone_vals <- df[[var]][df$has_zone == 0]
    zone_vals <- zone_vals[!is.na(zone_vals)]
    nonzone_vals <- nonzone_vals[!is.na(nonzone_vals)]

    cat("Zone municipalities:", length(zone_vals), "\n")
    cat("  Mean:", round(mean(zone_vals), 2), "\n")
    cat("  Median:", round(median(zone_vals), 2), "\n\n")
    cat("Non-zone municipalities:", length(nonzone_vals), "\n")
    cat("  Mean:", round(mean(nonzone_vals), 2), "\n")
    cat("  Median:", round(median(nonzone_vals), 2), "\n\n")

    if (length(zone_vals) > 1 & length(nonzone_vals) > 1) {
      tt <- t.test(zone_vals, nonzone_vals)
      cat("Difference:", round(mean(zone_vals) - mean(nonzone_vals), 2), "\n")
      cat("t-test p-value:", format.pval(tt$p.value, digits = 4), "\n")
    }
  })

  # ── Tab 3: Analysis ─────────────────────────────────────────────────────

  output$scatter_plot <- renderPlotly({
    df <- analysis_labeled()
    xvar <- input$scatter_x
    yvar <- input$scatter_y

    p <- ggplot(df %>% filter(!is.na(.data[[xvar]]) & !is.na(.data[[yvar]])),
                aes(x = .data[[xvar]], y = .data[[yvar]],
                    color = zone_status, text = municipality_name)) +
      geom_point(alpha = 0.4, size = 1.5) +
      scale_color_manual(values = c("Zone" = "#1D9E75", "Non-Zone" = "#E24B4A")) +
      labs(x = VAR_LABELS[xvar], y = VAR_LABELS[yvar], color = "") +
      theme_minimal()

    ggplotly(p, tooltip = c("text", "x", "y"))
  })

  output$corr_plot <- renderPlot({
    cor_data <- analysis %>%
      select(has_zone, all_of(COMPARE_VARS)) %>%
      filter(complete.cases(.))

    cor_mat <- cor(cor_data)
    corrplot::corrplot(cor_mat, method = "color", type = "upper",
                       tl.cex = 0.7, tl.col = "black",
                       addCoef.col = "black", number.cex = 0.6)
  })

  output$ttest_table <- renderDT({
    results <- lapply(COMPARE_VARS, function(v) {
      z <- analysis[[v]][analysis$has_zone == 1]
      nz <- analysis[[v]][analysis$has_zone == 0]
      z <- z[!is.na(z)]; nz <- nz[!is.na(nz)]
      if (length(z) > 1 & length(nz) > 1) {
        tt <- t.test(z, nz)
        data.frame(
          Variable = VAR_LABELS[v],
          Zone_Mean = round(mean(z), 2),
          NonZone_Mean = round(mean(nz), 2),
          Difference = round(mean(z) - mean(nz), 2),
          P_Value = round(tt$p.value, 4),
          stringsAsFactors = FALSE
        )
      }
    })

    do.call(rbind, results) %>%
      datatable(options = list(dom = "t", pageLength = 10), rownames = FALSE)
  })

  # ── Tab 4: Timeline ─────────────────────────────────────────────────────

  output$timeline_plot <- renderPlotly({
    z_dates <- zones %>% filter(!is.na(operational_date))

    p <- ggplot(z_dates, aes(x = operational_date)) +
      geom_histogram(binwidth = 5, fill = "#1D9E75", color = "white", alpha = 0.8) +
      labs(title = "Zone Establishment by Period",
           x = "Year", y = "Number of Zones") +
      theme_minimal()

    ggplotly(p)
  })

  output$cumulative_plot <- renderPlotly({
    z_dates <- zones %>%
      filter(!is.na(operational_date)) %>%
      arrange(operational_date) %>%
      mutate(cumulative = row_number())

    p <- ggplot(z_dates, aes(x = operational_date, y = cumulative)) +
      geom_step(color = "#2166AC", linewidth = 1.2) +
      geom_point(color = "#2166AC", size = 2, alpha = 0.6) +
      labs(title = "Cumulative Zone Count Over Time",
           x = "Year", y = "Cumulative Zones") +
      theme_minimal()

    ggplotly(p)
  })

  # ── Tab 5: Data Sources ────────────────────────────────────────────────

  output$sources_table <- renderDT({
    sources %>%
      datatable(options = list(pageLength = 19, scrollX = TRUE),
                filter = "top", rownames = FALSE)
  })
}

# ── RUN APP ──────────────────────────────────────────────────────────────────

shinyApp(ui, server)
