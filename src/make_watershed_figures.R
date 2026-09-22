library(terra)
library(dplyr)
library(tidyr)
library(ggplot2)

figure_dir <- "report_pngs"
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

indicator_files <- c(
  TreeCover = "../raster/somalia_mosaic_ld/treecover/somalia_treecover_2024_2025_250m.tif",
  Erosion   = "../raster/somalia_mosaic_ld/erosion/somalia_erosion_2024_2025_250m.tif",
  RDR50     = "../raster/somalia_mosaic_ld/RDR50/RDR50_2024_2025_250m.tif",
  pH        = "../raster/somalia_mosaic_ld/ph/somalia_ph_2024_2025_250m.tif",
  SOC       = "../raster/somalia_mosaic_ld/soc/somalia_2024_2025_soc.tif"
)

prob_stack <- rast("outputs_report/Raster/AARAN_cluster_probabilities_stack.tif")
names(prob_stack) <- c("lc", "mc", "hc")
concern_raster <- which.max(prob_stack)
names(concern_raster) <- "concern_id"
levels(concern_raster) <- data.frame(
  ID = 1:3,
  concern = c("Low concern", "Medium concern", "High concern")
)

ecosystem <- rast(indicator_files)
names(ecosystem) <- names(indicator_files)
NAflag(ecosystem) <- -9999

basins <- vect("../vector/basins_8_v2_dissolved.geojson")
clusters <- vect("../outputs_report/AARAN_V4_revised.geojson")

concern_cols <- c(
  "Low concern" = "#2A9D8F",
  "Medium concern" = "#E9C46A",
  "High concern" = "#E76F51"
)

indicator_labs <- c(
  TreeCover = "Tree cover (%)",
  Erosion = "Erosion (%)",
  RDR50 = "Root depth restriction at 50 cm",
  pH = "pH",
  SOC = "SOC (g/kg)"
)

sample_df <- read.csv("outputs_report/Vector_CSVs/sample_df_25k.csv") |>
  mutate(
    concern = recode(concern, "Least concern" = "Low concern"),
    concern = factor(concern, levels = names(concern_cols))
  )

country_medians <- sample_df |>
  summarise(across(all_of(names(indicator_files)), ~ median(.x, na.rm = TRUE))) |>
  pivot_longer(everything(), names_to = "Indicator", values_to = "Value") |>
  mutate(Scale = "Country")

zone_specs <- list(
  list(key = "watershed_1", basin = 1, clusters = "KAALO_6",
       title = "Watershed 1 and KAALO_6", display_clusters = "KAALO_6"),
  list(key = "watershed_2", basin = 2, clusters = "KAALO_1",
       title = "Watershed 2 and KAALO_1", display_clusters = "KAALO_1"),
  list(key = "watershed_3", basin = 3, clusters = "CWW_4",
       title = "Watershed 3 and CWW_4", display_clusters = "CWW_4"),
  list(key = "watershed_5_6", basin = c(5, 6), clusters = c("CREDO_6", "CREDO_7"),
       title = "Watersheds 5 and 6 with GREDO_6 and GREDO_7",
       display_clusters = "GREDO_6 and GREDO_7"),
  list(key = "watershed_7", basin = 7, clusters = "CWW_8",
       title = "Watershed 7 and CWW_8", display_clusters = "CWW_8"),
  list(key = "watershed_8", basin = 8, clusters = "KAALO_7",
       title = "Watershed 8 and KAALO_7", display_clusters = "KAALO_7")
)

read_zone_values <- function(poly, max_n = 70000) {
  zone_stack <- c(ecosystem, concern_raster)
  vals <- as.data.frame(mask(crop(zone_stack, poly), poly), na.rm = TRUE)
  if (!nrow(vals)) return(vals)
  vals <- vals |>
    filter(if_all(all_of(names(indicator_files)), ~ !is.na(.x) & .x != -9999)) |>
    mutate(
      pH = pH / 100,
      SOC = SOC / 100,
      concern = if ("concern" %in% names(vals)) {
        concern
      } else {
        c("Low concern", "Medium concern", "High concern")[concern_id]
      },
      concern = factor(concern, levels = names(concern_cols))
    ) |>
    filter(!is.na(concern))
  if (nrow(vals) > max_n) vals <- vals[sample.int(nrow(vals), max_n), ]
  vals
}

density_frame <- function(df) {
  df |>
    select(concern, all_of(names(indicator_files))) |>
    pivot_longer(all_of(names(indicator_files)), names_to = "Indicator", values_to = "Value") |>
    filter(!is.na(Value), !is.na(concern)) |>
    group_by(Indicator, concern) |>
    group_modify(~ {
      if (nrow(.x) < 3 || length(unique(.x$Value)) < 2) {
        return(tibble(Value = numeric(), density = numeric()))
      }
      dd <- density(.x$Value, na.rm = TRUE, n = 180)
      tibble(Value = dd$x, density = dd$y / max(dd$y, na.rm = TRUE))
    }) |>
    ungroup() |>
    mutate(
      ybase = as.numeric(concern),
      Indicator = factor(Indicator, levels = names(indicator_files), labels = indicator_labs)
    )
}

median_frame <- function(df, scale_name) {
  df |>
    summarise(across(all_of(names(indicator_files)), ~ median(.x, na.rm = TRUE))) |>
    pivot_longer(everything(), names_to = "Indicator", values_to = "Value") |>
    mutate(Scale = scale_name)
}

plot_ridges <- function(df, medians, title, out) {
  ridge_df <- density_frame(df)
  medians <- medians |>
    mutate(Indicator = factor(Indicator, levels = names(indicator_files), labels = indicator_labs))

  p <- ggplot(ridge_df, aes(x = Value)) +
    geom_ribbon(
      aes(ymin = ybase, ymax = ybase + density * 0.8, fill = concern),
      alpha = 0.72
    ) +
    geom_line(aes(y = ybase + density * 0.8, color = concern), linewidth = 0.35) +
    geom_vline(
      data = medians,
      aes(xintercept = Value, linetype = Scale),
      color = "black",
      linewidth = 0.45,
      inherit.aes = FALSE
    ) +
    facet_wrap(~Indicator, scales = "free_x", ncol = 2) +
    scale_y_continuous(
      breaks = seq_along(concern_cols) + 0.28,
      labels = names(concern_cols),
      expand = expansion(mult = c(0.02, 0.18))
    ) +
    scale_fill_manual(values = concern_cols) +
    scale_color_manual(values = concern_cols) +
    labs(title = title, x = NULL, y = NULL, fill = NULL, color = NULL, linetype = "Median") +
    theme_minimal(base_size = 13) +
    theme(
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold")
    )

  ggsave(out, p, width = 12, height = 8, dpi = 300, bg = "white")
}

centered_limits <- function(poly, pad = 0.10, panel_aspect = 0.78) {
  e <- ext(poly)
  x_mid <- (e[1] + e[2]) / 2
  y_mid <- (e[3] + e[4]) / 2
  x_range <- (e[2] - e[1]) * (1 + pad)
  y_range <- (e[4] - e[3]) * (1 + pad)
  target <- panel_aspect / cos(y_mid * pi / 180)

  if ((x_range / y_range) > target) {
    y_range <- x_range / target
  } else {
    x_range <- y_range * target
  }

  list(
    xlim = c(x_mid - x_range / 2, x_mid + x_range / 2),
    ylim = c(y_mid - y_range / 2, y_mid + y_range / 2)
  )
}

plot_zone_map <- function(zone_poly, cluster_poly, title, out) {
  z <- mask(crop(concern_raster, zone_poly), zone_poly)
  map_limits <- centered_limits(zone_poly)
  map_window <- rast(
    ext(map_limits$xlim[1], map_limits$xlim[2], map_limits$ylim[1], map_limits$ylim[2]),
    crs = crs(z),
    resolution = res(z)
  )
  tiles <- maptiles::get_tiles(
    map_window,
    provider = "OpenStreetMap",
    zoom = 8,
    crop = TRUE,
    verbose = FALSE
  )

  p <- ggplot() +
    ggspatial::layer_spatial(tiles) +
    tidyterra::geom_spatraster(data = z) +
    tidyterra::geom_spatvector(data = zone_poly, fill = NA, color = "black", linewidth = 0.55) +
    scale_fill_manual(
      values = concern_cols,
      labels = names(concern_cols),
      name = "Restoration concern",
      na.translate = FALSE,
      na.value = NA
    ) +
    ggspatial::annotation_scale(
      location = "bl",
      width_hint = 0.22,
      pad_x = grid::unit(0.9, "cm"),
      pad_y = grid::unit(1.05, "cm")
    ) +
    ggspatial::annotation_north_arrow(
      location = "tl",
      pad_x = grid::unit(0.55, "cm"),
      pad_y = grid::unit(0.55, "cm"),
      style = ggspatial::north_arrow_nautical
    ) +
    coord_sf(
      xlim = map_limits$xlim,
      ylim = map_limits$ylim,
      crs = sf::st_crs(4326),
      default_crs = sf::st_crs(4326),
      expand = FALSE
    ) +
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid = element_blank(),
      plot.title = element_text(face = "bold", hjust = 0.5, size = 15),
      legend.position = "bottom",
      legend.title = element_text(face = "bold")
    )

  if (!is.null(cluster_poly) && nrow(cluster_poly) > 0) {
    p <- p +
      tidyterra::geom_spatvector(data = cluster_poly, fill = NA, color = "#D7301F", linewidth = 0.75)
  }

  ggsave(out, p, width = 6.3, height = 7.4, dpi = 300, bg = "white")
}

cell_area_km2 <- cellSize(concern_raster, unit = "km")

area_by_concern <- function(poly, label) {
  vals <- as.data.frame(mask(crop(c(concern_raster, cell_area_km2), poly), poly), na.rm = TRUE)
  if (!nrow(vals)) return(tibble())
  names(vals)[names(vals) == names(cell_area_km2)] <- "area_km2"
  if (!"concern" %in% names(vals)) {
    vals$concern <- c("Low concern", "Medium concern", "High concern")[vals$concern_id]
  }
  vals |>
    mutate(concern = factor(concern, levels = names(concern_cols))) |>
    group_by(concern) |>
    summarise(area_km2 = sum(area_km2, na.rm = TRUE), .groups = "drop") |>
    complete(concern = factor(names(concern_cols), levels = names(concern_cols)), fill = list(area_km2 = 0)) |>
    mutate(zone = label, share = area_km2 / sum(area_km2))
}

plot_composition <- function(df, title, out) {
  p <- ggplot(df, aes(share, reorder(zone, share * (concern == "High concern")), fill = concern)) +
    geom_col(width = 0.72) +
    scale_x_continuous(labels = scales::percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.02))) +
    scale_fill_manual(values = concern_cols, drop = FALSE) +
    labs(title = title, x = "Share of area", y = NULL, fill = NULL) +
    theme_minimal(base_size = 14) +
    theme(
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold")
    )
  ggsave(out, p, width = 10.5, height = 7, dpi = 300, bg = "white")
}

watershed_composition <- bind_rows(lapply(sort(unique(basins$cluster_id)), function(id) {
  area_by_concern(basins[basins$cluster_id == id, ], paste("Watershed", id))
}))
plot_composition(
  watershed_composition,
  "Restoration Concern Composition by Watershed",
  file.path(figure_dir, "AARAN_watershed_composition.png")
)

cluster_order <- c("KAALO_7", "KAALO_6", "KAALO_1", "CWW_4", "CREDO_7", "CREDO_6", "CWW_8")
cluster_composition <- bind_rows(lapply(cluster_order, function(cluster_name) {
  display_name <- sub("^CREDO", "GREDO", cluster_name)
  area_by_concern(clusters[clusters$Cluster == cluster_name, ], display_name)
}))
plot_composition(
  cluster_composition,
  "Restoration Concern Composition by Selected Clusters",
  file.path(figure_dir, "AARAN_cluster_composition.png")
)

for (spec in zone_specs) {
  message("Generating figures for ", spec$title)
  zone_poly <- basins[basins$cluster_id %in% spec$basin, ]
  cluster_poly <- clusters[clusters$Cluster %in% spec$clusters, ]

  zone_df <- read_zone_values(zone_poly)
  cluster_df <- if (nrow(cluster_poly) > 0) read_zone_values(cluster_poly) else zone_df[0, ]

  zone_medians <- bind_rows(
    country_medians,
    median_frame(zone_df, "Watershed")
  )
  cluster_medians <- bind_rows(
    zone_medians,
    median_frame(cluster_df, "Cluster")
  )

  plot_zone_map(
    zone_poly,
    cluster_poly,
    paste0(spec$title, " restoration concern"),
    file.path(figure_dir, paste0("AARAN_", spec$key, "_map.png"))
  )
  plot_ridges(
    zone_df,
    zone_medians,
    paste0(spec$title, " watershed indicator distributions"),
    file.path(figure_dir, paste0("AARAN_", spec$key, "_watershed_ridges.png"))
  )
  if (nrow(cluster_df) > 0) {
    plot_ridges(
      cluster_df,
      cluster_medians,
      paste0(spec$display_clusters, " cluster indicator distributions"),
      file.path(figure_dir, paste0("AARAN_", spec$key, "_cluster_ridges.png"))
    )

    if (length(spec$clusters) > 1) {
      for (cluster_name in spec$clusters) {
        one_cluster_poly <- clusters[clusters$Cluster == cluster_name, ]
        one_cluster_df <- read_zone_values(one_cluster_poly)
        if (!nrow(one_cluster_df)) next
        display_name <- sub("^CREDO", "GREDO", cluster_name)
        one_cluster_medians <- bind_rows(
          zone_medians,
          median_frame(one_cluster_df, "Cluster")
        )
        plot_ridges(
          one_cluster_df,
          one_cluster_medians,
          paste0(display_name, " cluster indicator distributions"),
          file.path(figure_dir, paste0("AARAN_", spec$key, "_", tolower(cluster_name), "_ridges.png"))
        )
      }
    }
  }
}
