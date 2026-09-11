library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(ggplot2)

raster_dir <- "outputs_report/Raster"
points_file <- "outputs_report/Vector_CSVs/sample_df.csv"
figure_dir <- "report_pngs"
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

indicator_files <- c(
  TreeCover = file.path(raster_dir, "somalia_treecover_2024_2025_250m.tif"),
  Erosion   = file.path(raster_dir, "somalia_erosion_2024_2025_250m.tif"),
  RDR50     = file.path(raster_dir, "RDR50_2024_2025_250m.tif"),
  pH        = file.path(raster_dir, "somalia_ph_2024_2025_250m.tif"),
  SOC       = file.path(raster_dir, "somalia_2024_2025_soc.tif")
)

ecosystem <- rast(indicator_files)
names(ecosystem) <- names(indicator_files)
NAflag(ecosystem) <- -9999

pts_sf <- read.csv(points_file) |>
  st_as_sf(coords = c("x", "y"), crs = 4326, remove = FALSE)

pts_sf <- st_transform(pts_sf, crs(ecosystem))

## Extract
predictors <- names(indicator_files)

sample_df <- terra::extract(ecosystem, pts_sf, ID = FALSE) |>
  bind_cols(st_drop_geometry(pts_sf)) |>
  tidyr::drop_na(all_of(predictors)) |>
  mutate(SOC = SOC / 100, pH = pH / 100)

summary(sample_df)

indicator_cols <- c(
  Erosion   = "red",
  RDR50     = "blue",
  SOC       = "brown",
  TreeCover = "green",
  pH        = "purple"
)

indicator_units <- c(
  Erosion   = "Erosion (%)",
  RDR50     = "RDR50 (%)",
  SOC       = "SOC (g/kg)",
  TreeCover = "Tree Cover (%)",
  pH        = "pH"
)

## Force erosion, etc to 0-100 y-axis
pct_range <- expand.grid(
  Indicator = c("Erosion", "RDR50", "TreeCover"),
  Value = c(0, 100)
)

indicator_plot <- sample_df |>
  select(all_of(predictors)) |>
  pivot_longer(everything(), names_to = "Indicator", values_to = "Value") |>
  ggplot(aes(Indicator, Value, fill = Indicator)) +
  geom_violin(alpha = 0.4, trim = FALSE) +
  geom_boxplot(width = 0.15, outlier.alpha = 0.1) +
  geom_blank(data = pct_range) +
  facet_wrap(~Indicator, scales = "free", labeller = labeller(Indicator = indicator_units)) +
  scale_fill_manual(values = indicator_cols) +
  labs(x = NULL, y = NULL) +
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    legend.position = "none"
  )

ggsave(
  file.path(figure_dir, "AARAN_indicator_distributions.png"),
  indicator_plot,
  width = 9, height = 6, dpi = 300
)
