#' looSTAAR: Leave-One-Out STAAR-O Influence Function (Parallelized)
#'
#' Iteratively removes each variant from the set and reruns STAAR-O
#' to quantify its influence on the gene-based association p-value.
#'
#' @param genotype_matrix Matrix of 0/1/2 dosages (samples x variants)
#' @param obj_nullmodel Output from fit_null_glm()
#' @param maf_cutoff Minor allele frequency cutoff (default = 0.01)
#' @param n_cores Number of CPU cores to use for parallel processing (default = 4)
#'
#' @return Data.frame with Variant_ID, Baseline_STAAR_O_pval, LOO_STAAR_O_pval, Delta_log10p
#' @export
#'
#' @examples
#' \dontrun{
#' if (requireNamespace("STAAR", quietly = TRUE)) {
#'   library(STAAR)
#'   set.seed(123)
#'   data <- matrix(rbinom(2500000, 2, 0.005), nrow = 5000, ncol = 500)
#'   colnames(data) <- paste0("var", 1:500)
#'   pheno_data <- data.frame(y = rnorm(5000))
#'   null_model <- fit_null_glm(y ~ 1, family = gaussian(), data = pheno_data)
#'   result <- looSTAAR(data[, 1:20], null_model, maf_cutoff = 0.01, n_cores = 2)
#'   head(result)
#' }
#' }
#'
#' @importFrom parallel mclapply
looSTAAR <- function(genotype_matrix, obj_nullmodel, maf_cutoff = 0.01, n_cores = 4) {
  if (!requireNamespace("STAAR", quietly = TRUE)) {
    stop("The STAAR package is required. Please install it with devtools::install_github('xihaoli/STAAR').")
  }
  library(STAAR)  # Load STAAR if available
  if (is.null(colnames(genotype_matrix)) || length(colnames(genotype_matrix)) == 0) {
    stop("genotype_matrix must have non-empty variant IDs as column names.")
  }
  if (!is.matrix(genotype_matrix) || !is.numeric(genotype_matrix)) {
    stop("genotype_matrix must be a numeric matrix.")
  }
  if (nrow(genotype_matrix) < 2) {
    stop("genotype_matrix must have at least 2 samples.")
  }

  message("Running full STAAR to get baseline p-value...")
  baseline <- STAAR(
    genotype = genotype_matrix,
    obj_nullmodel = obj_nullmodel,
    rare_maf_cutoff = maf_cutoff,
    rv_num_cutoff = 2
  )
  baseline_p <- baseline$results_STAAR_O
  if (length(baseline_p) != 1) {
    warning("Multiple p-values returned by STAAR-O; using the first one.")
    baseline_p <- baseline_p[1]
  }

  message("Running leave-one-out analysis in parallel using ", n_cores, " cores...")
  results <- parallel::mclapply(seq_len(ncol(genotype_matrix)), function(i) {
    geno_subset <- genotype_matrix[, -i, drop = FALSE]
    if (ncol(geno_subset) < 1) {
      warning("Skipping variant ", colnames(genotype_matrix)[i], ": no variants remain after exclusion.")
      return(data.frame(Variant_ID = colnames(genotype_matrix)[i], Baseline_STAAR_O_pval = NA, LOO_STAAR_O_pval = NA, Delta_log10p = NA))
    }
    pval <- tryCatch({
      STAAR(
        genotype = geno_subset,
        obj_nullmodel = obj_nullmodel,
        rare_maf_cutoff = maf_cutoff,
        rv_num_cutoff = 2
      )$results_STAAR_O[1]
    }, error = function(e) {
      warning("Error for variant ", colnames(genotype_matrix)[i], ": ", e$message)
      NA
    })
    data.frame(
      Variant_ID = colnames(genotype_matrix)[i],
      Baseline_STAAR_O_pval = baseline_p,
      LOO_STAAR_O_pval = pval,
      Delta_log10p = if (is.na(pval)) NA else log10(baseline_p) - log10(pval)
    )
  }, mc.cores = n_cores)

  do.call(rbind, results)
}

#' Plot LOO STAAR-O Influence
#'
#' Creates a scatter plot of Delta_log10p against genomic position, highlighting
#' driver and diluter variants.
#'
#' @param results Data.frame with columns: Variant_ID, Delta_log10p, Position
#' @param variant_info Optional data.frame with Variant_ID and Position (if not in results)
#' @param title Plot title (default: "Leave-One-Out Influence on STAAR-O")
#' @param ylim Y-axis limits (default: c(-1.2, 1.2))
#'
#' @return ggplot object
#' @export
#'
#' @examples
#' \dontrun{
#' if (requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("ggrepel", quietly = TRUE)) {
#'   results <- data.frame(Variant_ID = paste0("var", 1:100), Delta_log10p = runif(100, -0.01, 0.01))
#'   results$Position <- 1:100
#'   plot_looSTAAR(results)
#' }
#' }
plot_looSTAAR <- function(results, variant_info = NULL, title = "Leave-One-Out Influence on STAAR-O", ylim = c(-1.2, 1.2)) {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !requireNamespace("ggrepel", quietly = TRUE)) {
    stop("ggplot2 and ggrepel packages are required for plotting. Please install them.")
  }
  library(ggplot2)
  library(ggrepel)

  # Merge position info if provided
  if (!is.null(variant_info) && "Position" %in% colnames(variant_info)) {
    results <- merge(results, variant_info[, c("Variant_ID", "Position")], by = "Variant_ID", all.x = TRUE)
  } else if (!"Position" %in% colnames(results)) {
    stop("Position column or variant_info with Position is required.")
  }

  # Add label for extreme influencers
  results$label <- ifelse(abs(results$Delta_log10p) > 0.1, as.character(results$Variant_ID), NA)

  # Define effect type
  results$Effect <- ifelse(
    results$Delta_log10p > 0,
    "Diluter: masks signal",
    "Driver: contributes to signal"
  )

  # Create plot
  p <- ggplot(results, aes(x = Position, y = Delta_log10p, color = Effect)) +
    geom_point(size = 1.5, show.legend = TRUE) +
    geom_text_repel(aes(label = label), size = 6, max.overlaps = Inf, show.legend = FALSE) +
    scale_color_manual(
      values = c(
        "Driver: contributes to signal" = "#1b9e77",
        "Diluter: masks signal"          = "#d95f02"
      ),
      name = "Variant Effect"
    ) +
    guides(color = guide_legend(override.aes = list(size = 4))) +
    theme_light(base_size = 14) +
    labs(
      title = title,
      x = "Genomic Position (bp)",
      y = expression(Delta*log[10](p))
    ) +
    theme(
      plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "top"
    ) +
    coord_cartesian(ylim = ylim)

  # Return plot (save option left to user)
  p
}
