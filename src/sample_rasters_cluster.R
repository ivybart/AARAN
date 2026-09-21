library(terra)
library(dplyr)
library(tidyr)
library(ggplot2)
library(mclust)
library(ranger)

# Set random seed for reproducibility
set.seed(42)

# Define directories
raster_dir <- "outputs_report/Raster"
output_dir <- "outputs_report/Vector_CSVs"
models_dir <- "outputs_report/Models"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(models_dir, showWarnings = FALSE, recursive = TRUE)

# Flag: skip raster predictions and reuse existing sample/model outputs
# Usage: Rscript src/sample_rasters_cluster.R --skip-predict
skip_predict <- "--skip-predict" %in% commandArgs(trailingOnly = TRUE)
sample_csv <- file.path(output_dir, "sample_df_25k.csv")
model_rds <- file.path(models_dir, "AARAN_ranger_cluster.rds")

predictors <- c("TreeCover", "Erosion", "RDR50", "pH", "SOC")

if (skip_predict && file.exists(sample_csv) && file.exists(model_rds)) {
  cat("Flag --skip-predict set: loading existing sample and model.\n")
  sample_df <- read.csv(sample_csv)
  sample_df$cluster_label <- factor(sample_df$cluster_label, levels = c("lc", "mc", "hc"))
  rf_cluster <- readRDS(model_rds)
} else {
  if (skip_predict) {
    cat("Flag --skip-predict set but existing sample/model not found; running full workflow.\n")
  }

  # Target sample size
  target_n <- 25000

# Define indicator raster files
indicator_files <- c(
  TreeCover = file.path(raster_dir, "somalia_treecover_2024_2025_250m.tif"),
  Erosion   = file.path(raster_dir, "somalia_erosion_2024_2025_250m.tif"),
  RDR50     = file.path(raster_dir, "RDR50_2024_2025_250m.tif"),
  pH        = file.path(raster_dir, "somalia_ph_2024_2025_250m.tif"),
  SOC       = file.path(raster_dir, "somalia_2024_2025_soc.tif")
)

# Load raster stack and configure NA flag (-9999 represents missing/NULL values)
ecosystem <- rast(indicator_files)
names(ecosystem) <- names(indicator_files)
NAflag(ecosystem) <- -9999

cat("Reading raster values and identifying non-missing cells...\n")

# Extract all layer values to identify valid pixels efficiently
vals <- values(ecosystem, dataframe = TRUE)

# Drop missing values: exclude NA, NaN, and explicit -9999 values across all indicators
valid_cells <- which(
  complete.cases(vals) &
  rowSums(vals == -9999 | is.na(vals)) == 0
)

cat(sprintf("Found %s complete, valid raster cells.\n", format(length(valid_cells), big.mark = ",")))

# Randomly sample ~25,000 cells without replacement from valid cells
sampled_cell_ids <- sample(valid_cells, size = min(target_n, length(valid_cells)), replace = FALSE)

# Extract spatial coordinates (x = lon, y = lat) for the sampled cells
coords <- xyFromCell(ecosystem, sampled_cell_ids)

# Assemble data frame with coordinates and indicator values
sample_df <- cbind(
  tibble::tibble(
    plot_id = seq_along(sampled_cell_ids),
    cell_id = sampled_cell_ids,
    x = coords[, 1],
    y = coords[, 2]
  ),
  vals[sampled_cell_ids, ]
)

# Adjust units: convert raw integer storage (pH * 100, SOC * 100) to standard units
sample_df <- sample_df |>
  mutate(
    pH = pH / 100,
    SOC = SOC / 100
  )

cat(sprintf("Successfully sampled %d plots. Summary of sampled indicators:\n", nrow(sample_df)))
print(summary(sample_df[, c("TreeCover", "Erosion", "RDR50", "pH", "SOC")]))

# Save sampled plots to CSV
output_csv <- file.path(output_dir, "sample_df_25k.csv")
write.csv(sample_df, output_csv, row.names = FALSE)
cat(sprintf("Saved sampled points to: %s\n", output_csv))

# ------------------------------------------------------------------------------
# Clustering (Mclust / GMM)
# ------------------------------------------------------------------------------
sample_scaled <- scale(as.matrix(sample_df[, predictors]))
gmm_model <- Mclust(sample_scaled, G = 3, verbose = FALSE)
sample_df$cluster <- as.integer(gmm_model$classification)

# Plot Erosion and SOC distributions per cluster
sample_df |>
  ggplot() +
  geom_boxplot(aes(as.factor(cluster), SOC)) +
  geom_boxplot(aes(as.factor(cluster), pH), fill="brown")

# Label the clusters as 1 == "hc", 2 == "mc", 3 == "lc"
sample_df <- sample_df |>
  mutate(
    cluster_label = case_when(
      cluster == 1 ~ "hc",
      cluster == 2 ~ "mc",
      cluster == 3 ~ "lc"
    ),
    concern = case_when(
      cluster_label == "hc" ~ "High concern",
      cluster_label == "mc" ~ "Medium concern",
      cluster_label == "lc" ~ "Least concern"
    )
  )

cat("Cluster summary by assigned label:\n")
print(table(Cluster = sample_df$cluster, Label = sample_df$cluster_label, Concern = sample_df$concern))

# Save sampled plots with cluster assignments to CSV
output_csv <- file.path(output_dir, "sample_df_25k.csv")
write.csv(sample_df, output_csv, row.names = FALSE)

# Model cluster membership using ranger
sample_df$cluster_label <- factor(sample_df$cluster_label, levels = c("lc", "mc", "hc"))

rf_cluster <- ranger(
  formula = cluster_label ~ TreeCover + Erosion + RDR50 + pH + SOC,
  data = sample_df,
  probability = TRUE,
  importance = "impurity",
  num.trees = 500,
  seed = 42
)

print(rf_cluster)
print(importance(rf_cluster))

# Save model
saveRDS(rf_cluster, model_rds)
}

# ------------------------------------------------------------------------------
# Density plots for each indicator by cluster concern level
# ------------------------------------------------------------------------------
concern_cols <- c(
  "Least concern"  = "#058005",
  "Medium concern" = "blue",
  "High concern"   = "red"
)

sample_df |>
  mutate(concern = factor(concern, levels = c("Least concern", "Medium concern", "High concern"))) |>
  pivot_longer(all_of(predictors), names_to = "Indicator", values_to = "Value") |>
  ggplot(aes(x = Value, fill = concern, color = concern)) +
  geom_density(alpha = 0.4) +
  facet_wrap(~Indicator, scales = "free", ncol=1) +
  scale_fill_manual(values = concern_cols) +
  scale_color_manual(values = concern_cols) +
  labs(fill = "Concern", color = "Concern", x = "Value", y = "Density") +
  theme_minimal()

# ------------------------------------------------------------------------------
# Variable importance: one panel per class (one-vs-rest RF models)
# ------------------------------------------------------------------------------
figure_dir <- "report_pngs"
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

class_labels <- c(
  lc = "Low restoration effort",
  mc = "Medium restoration effort",
  hc = "High restoration effort"
)
effort_cols <- c("red", "#058005", "blue")

imp_list <- lapply(names(class_labels), function(cl) {
  df <- sample_df
  df$.target <- factor(df$cluster_label == cl, levels = c(TRUE, FALSE))
  m <- ranger(
    .target ~ TreeCover + Erosion + RDR50 + pH + SOC,
    data = df,
    probability = TRUE,
    importance = "impurity",
    num.trees = 500,
    seed = 42
  )
  tibble(
    Indicator = names(importance(m)),
    Importance = as.numeric(importance(m)),
    Class = unname(class_labels[cl])
  )
})
imp_df <- bind_rows(imp_list) |>
  mutate(
    Class = factor(Class, levels = c(
      "Low restoration effort", "Medium restoration effort", "High restoration effort"
    ))
  )

imp_df |>
  ggplot(aes(x = reorder(Indicator, Importance), y = Importance, fill = Class)) +
  geom_col(width = 0.7) +
  facet_wrap(~Class, ncol = 3) +
  coord_flip() +
  scale_fill_manual(values = c(
    "Low restoration effort" = "#2A9D8F",
    "Medium restoration effort" = "#E9C46A",
    "High restoration effort" = "#E76F51"
  )) +
  labs(
    title = "Variable importance for class prediction",
    x = NULL,
    y = "Importance (mean decrease in impurity)"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none", strip.text = element_text(face = "bold"))

ggsave(
  file.path(figure_dir, "AARAN_importance.png"),
  width = 9, height = 3.5, dpi = 300
)
cat(sprintf("Saved variable importance figure to: %s\n",
            file.path(figure_dir, "AARAN_importance.png")))

# ------------------------------------------------------------------------------
# Predict cluster probabilities across the input rasters
# ------------------------------------------------------------------------------
if (skip_predict) {
  cat("Flag --skip-predict set: skipping raster predictions.\n")
} else {
  # Scale pH and SOC layers to match the units used during model training
  ecosystem_scaled <- ecosystem
  ecosystem_scaled$pH <- ecosystem_scaled$pH / 100
  ecosystem_scaled$SOC <- ecosystem_scaled$SOC / 100

  # Prediction function returning: band 1 == "lc", band 2 == "mc", band 3 == "hc"
  # Probabilities (0-1) are scaled to percent (0-100)
  pred_fun <- function(model, data) {
    predict(model, data = data)$predictions[, c("lc", "mc", "hc")] * 100
  }

  output_stack_file <- file.path(raster_dir, "AARAN_cluster_probabilities_stack.tif")

  cat("Predicting cluster probabilities onto raster stack...\n")
  prob_stack <- terra::predict(
    ecosystem_scaled,
    rf_cluster,
    fun = pred_fun,
    na.rm = TRUE,
    filename = output_stack_file,
    overwrite = TRUE
  )

  names(prob_stack) <- c("lc", "mc", "hc")
  cat(sprintf("Saved probability stack to: %s\n", output_stack_file))
}
