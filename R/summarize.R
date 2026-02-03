#' Region Embedding Summarization
#'
#' Functions for computing summary embeddings over geographic regions.
#' These functions download embeddings to a temporary location, compute
#' summaries, and clean up automatically.
#'
#' @name summarize
#' @keywords internal
NULL

# Default summary functions -------------------------------------------------

#' Mean Embedding Summary
#'
#' Computes the mean embedding across all valid pixels in the region.
#'
#' @param embeddings List of 3D arrays (height, width, channels) from tiles
#' @param region sf object or bbox defining the region (used for masking)
#' @param tiles_df Data frame of tile metadata
#' @return Named numeric vector of length 128 (mean embedding)
#' @export
#' @examples
#' \dontrun{
#' gt <- geotessera()
#' result <- gt$summarize_region(
#'   region = c(0.08, 52.18, 0.15, 52.21),
#'   year = 2024,
#'   summary_fns = list(mean = summary_mean)
#' )
#' }
summary_mean <- function(embeddings, region = NULL, tiles_df = NULL) {
  # Stack all embeddings into a 2D matrix (pixels x channels)
  all_pixels <- do.call(rbind, lapply(embeddings, function(emb) {
    dims <- dim(emb)
    matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])
  }))

  # Remove NA rows
  valid_rows <- complete.cases(all_pixels)
  if (sum(valid_rows) == 0) {
    return(rep(NA_real_, EMBEDDING_CHANNELS))
  }

  result <- colMeans(all_pixels[valid_rows, , drop = FALSE])
  names(result) <- paste0("dim_", seq_along(result))
  result
}

#' Median Embedding Summary
#'
#' Computes the median embedding across all valid pixels in the region.
#'
#' @inheritParams summary_mean
#' @return Named numeric vector of length 128 (median embedding)
#' @export
summary_median <- function(embeddings, region = NULL, tiles_df = NULL) {
  all_pixels <- do.call(rbind, lapply(embeddings, function(emb) {
    dims <- dim(emb)
    matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])
  }))

  valid_rows <- complete.cases(all_pixels)
  if (sum(valid_rows) == 0) {
    return(rep(NA_real_, EMBEDDING_CHANNELS))
  }

  result <- apply(all_pixels[valid_rows, , drop = FALSE], 2, median)
  names(result) <- paste0("dim_", seq_along(result))
  result
}

#' Centroid Embedding Summary
#'
#' Samples the embedding at the geographic centroid of the region.
#'
#' @inheritParams summary_mean
#' @param gt GeoTessera object (passed automatically by summarize_region)
#' @param year Integer year (passed automatically by summarize_region)
#' @return Named numeric vector of length 128 (centroid embedding)
#' @export
summary_centroid <- function(embeddings, region = NULL, tiles_df = NULL,
                              gt = NULL, year = NULL) {
  if (is.null(region) || is.null(gt) || is.null(year)) {
    cli::cli_abort("summary_centroid requires region, gt, and year parameters")
  }


  # Get centroid coordinates
  if (inherits(region, "sf") || inherits(region, "sfc")) {
    centroid <- sf::st_centroid(sf::st_union(region))
    coords <- sf::st_coordinates(centroid)
    lon <- coords[1, 1]
    lat <- coords[1, 2]
  } else {
    # bbox format
    bounds <- format_bbox(region)
    lon <- (bounds$xmin + bounds$xmax) / 2
    lat <- (bounds$ymin + bounds$ymax) / 2
  }

  # Sample at centroid
  tryCatch({
    tile <- gt$download_tile(lon, lat, year, progress = FALSE)
    result <- tile$sample_at_point(lon, lat)
    names(result) <- paste0("dim_", seq_along(result))
    result
  }, error = function(e) {
    cli::cli_warn("Could not sample at centroid: {e$message}")
    result <- rep(NA_real_, EMBEDDING_CHANNELS)
    names(result) <- paste0("dim_", seq_len(EMBEDDING_CHANNELS))
    result
  })
}

#' Standard Deviation Summary
#'
#' Computes the standard deviation of embeddings across all valid pixels.
#'
#' @inheritParams summary_mean
#' @return Named numeric vector of length 128 (per-dimension std dev)
#' @export
summary_sd <- function(embeddings, region = NULL, tiles_df = NULL) {
  all_pixels <- do.call(rbind, lapply(embeddings, function(emb) {
    dims <- dim(emb)
    matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])
  }))

  valid_rows <- complete.cases(all_pixels)
  if (sum(valid_rows) < 2) {
    return(rep(NA_real_, EMBEDDING_CHANNELS))
  }

  result <- apply(all_pixels[valid_rows, , drop = FALSE], 2, sd)
  names(result) <- paste0("dim_", seq_along(result))
  result
}

#' Quantile Summary
#'
#' Factory function to create a quantile summary function.
#'
#' @param probs Numeric vector of probabilities (0-1)
#' @return A summary function that computes the specified quantiles
#' @export
#' @examples
#' \dontrun{
#' # Create a function for 25th and 75th percentiles
#' summary_q25_75 <- summary_quantile(c(0.25, 0.75))
#'
#' gt <- geotessera()
#' result <- gt$summarize_region(
#'   region = bbox,
#'   year = 2024,
#'   summary_fns = list(quantiles = summary_q25_75)
#' )
#' }
summary_quantile <- function(probs = c(0.25, 0.5, 0.75)) {
  force(probs)
  function(embeddings, region = NULL, tiles_df = NULL) {
    all_pixels <- do.call(rbind, lapply(embeddings, function(emb) {
      dims <- dim(emb)
      matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])
    }))

    valid_rows <- complete.cases(all_pixels)
    if (sum(valid_rows) == 0) {
      n_quantiles <- length(probs)
      result <- rep(NA_real_, EMBEDDING_CHANNELS * n_quantiles)
      names(result) <- paste0("dim_", rep(seq_len(EMBEDDING_CHANNELS), each = n_quantiles),
                              "_q", rep(probs * 100, EMBEDDING_CHANNELS))
      return(result)
    }

    quantiles <- apply(all_pixels[valid_rows, , drop = FALSE], 2,
                       quantile, probs = probs)

    if (length(probs) == 1) {
      result <- as.vector(quantiles)
      names(result) <- paste0("dim_", seq_along(result), "_q", probs * 100)
    } else {
      result <- as.vector(quantiles)
      names(result) <- paste0("dim_", rep(seq_len(EMBEDDING_CHANNELS), each = length(probs)),
                              "_q", rep(probs * 100, EMBEDDING_CHANNELS))
    }
    result
  }
}

#' Random Sample Summary
#'
#' Factory function to create a random sampling summary function.
#'
#' @param n Number of random points to sample
#' @param seed Random seed for reproducibility (NULL for no seed)
#' @return A summary function that returns embeddings at n random points
#' @export
#' @examples
#' \dontrun{
#' summary_random_10 <- summary_random_sample(n = 10, seed = 42)
#'
#' gt <- geotessera()
#' result <- gt$summarize_region(
#'   region = bbox,
#'   year = 2024,
#'   summary_fns = list(samples = summary_random_10)
#' )
#' }
summary_random_sample <- function(n = 10, seed = NULL) {
  force(n)
  force(seed)

  function(embeddings, region = NULL, tiles_df = NULL) {
    if (!is.null(seed)) set.seed(seed)

    all_pixels <- do.call(rbind, lapply(embeddings, function(emb) {
      dims <- dim(emb)
      matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])
    }))

    valid_rows <- which(complete.cases(all_pixels))
    if (length(valid_rows) == 0) {
      result <- matrix(NA_real_, nrow = n, ncol = EMBEDDING_CHANNELS)
      colnames(result) <- paste0("dim_", seq_len(EMBEDDING_CHANNELS))
      rownames(result) <- paste0("sample_", seq_len(n))
      return(result)
    }

    sample_size <- min(n, length(valid_rows))
    sampled_idx <- sample(valid_rows, sample_size)

    result <- all_pixels[sampled_idx, , drop = FALSE]
    colnames(result) <- paste0("dim_", seq_len(ncol(result)))
    rownames(result) <- paste0("sample_", seq_len(nrow(result)))

    if (sample_size < n) {
      # Pad with NAs if not enough valid pixels
      padding <- matrix(NA_real_, nrow = n - sample_size, ncol = EMBEDDING_CHANNELS)
      colnames(padding) <- colnames(result)
      rownames(padding) <- paste0("sample_", (sample_size + 1):n)
      result <- rbind(result, padding)
    }

    result
  }
}

#' Pixel Count Summary
#'
#' Returns the count of valid (non-NA) pixels in the region.
#'
#' @inheritParams summary_mean
#' @return Named integer with valid and total pixel counts
#' @export
summary_pixel_count <- function(embeddings, region = NULL, tiles_df = NULL) {
  total <- 0
  valid <- 0

  for (emb in embeddings) {
    dims <- dim(emb)
    n_pixels <- dims[1] * dims[2]
    total <- total + n_pixels

    # Check first channel for NA (all channels should be NA together)
    valid <- valid + sum(!is.na(emb[, , 1]))
  }

  c(valid_pixels = valid, total_pixels = total)
}

#' Coverage Statistics Summary
#'
#' Returns coverage statistics for the region including tile count and area.
#'
#' @inheritParams summary_mean
#' @return Named vector with coverage statistics
#' @export
summary_coverage <- function(embeddings, region = NULL, tiles_df = NULL) {
  n_tiles <- length(embeddings)
  n_valid_pixels <- 0
  n_total_pixels <- 0

  for (emb in embeddings) {
    dims <- dim(emb)
    n_total_pixels <- n_total_pixels + dims[1] * dims[2]
    n_valid_pixels <- n_valid_pixels + sum(!is.na(emb[, , 1]))
  }

  coverage_pct <- if (n_total_pixels > 0) {
    100 * n_valid_pixels / n_total_pixels
  } else {
    0
  }

  c(
    n_tiles = n_tiles,
    n_valid_pixels = n_valid_pixels,
    n_total_pixels = n_total_pixels,
    coverage_percent = coverage_pct
  )
}


#' Streaming Mean Summary (Memory Efficient)
#'
#' Computes mean embedding using Welford's online algorithm, processing
#' one tile at a time without storing all embeddings in memory.
#' Ideal for large regions with many tiles.
#'
#' @param gt GeoTessera object
#' @param tiles_df Data frame of tile metadata
#' @param year Integer year
#' @param region sf object for masking (optional)
#' @param sample_rate Fraction of pixels to sample (0-1). Default 1.0 (all pixels).
#'   Use lower values for faster processing of very large regions.
#' @param seed Random seed for sampling (if sample_rate < 1)
#' @param progress Show progress
#' @return Named list with mean embedding and pixel count
#' @export
#' @examples
#' \dontrun{
#' gt <- geotessera()
#' tiles_df <- gt$get_tiles(bbox, year = 2024)
#' result <- summary_mean_streaming(gt, tiles_df, 2024)
#' }
summary_mean_streaming <- function(gt, tiles_df, year, region = NULL,
                                    sample_rate = 1.0, seed = NULL,
                                    progress = TRUE) {
  if (!is.null(seed)) set.seed(seed)

  # Initialize running statistics (Welford's algorithm)
  n <- 0
  mean_acc <- rep(0, EMBEDDING_CHANNELS)

  if (progress) {
    cli::cli_progress_bar("Processing tiles", total = nrow(tiles_df))
  }

  for (i in seq_len(nrow(tiles_df))) {
    tile_info <- tiles_df[i, ]

    tryCatch({
      # Download and load single tile
      tile <- gt$download_tile(
        tile_info$lon, tile_info$lat, year,
        progress = FALSE
      )
      emb <- tile$load_embedding()
      dims <- dim(emb)

      # Reshape to matrix (pixels x channels)
      pixels <- matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])

      # Apply spatial mask if region is sf
      if (!is.null(region) && (inherits(region, "sf") || inherits(region, "sfc"))) {
        bounds <- tile$get_bounds()
        x_coords <- seq(bounds$xmin, bounds$xmax, length.out = dims[2])
        y_coords <- seq(bounds$ymax, bounds$ymin, length.out = dims[1])

        # Create coordinate matrix (more memory efficient than sf points)
        coord_grid <- expand.grid(x = x_coords, y = y_coords)

        # Use terra for faster point-in-polygon (if available)
        if (requireNamespace("terra", quietly = TRUE)) {
          region_vect <- terra::vect(region)
          pts <- terra::vect(as.matrix(coord_grid), crs = "EPSG:4326")
          inside <- !is.na(terra::extract(terra::rasterize(region_vect,
            terra::rast(ext = terra::ext(region_vect), res = 0.0001)), pts)[, 2])
        } else {
          # Fallback: sample-based check (approximate but memory efficient)
          pts <- sf::st_as_sf(coord_grid, coords = c("x", "y"), crs = 4326)
          inside <- lengths(sf::st_intersects(pts, sf::st_transform(region, 4326))) > 0
        }

        pixels[!inside, ] <- NA
      }

      # Sample if requested
      valid_idx <- which(complete.cases(pixels))
      if (sample_rate < 1.0 && length(valid_idx) > 0) {
        n_sample <- max(1, floor(length(valid_idx) * sample_rate))
        valid_idx <- sample(valid_idx, n_sample)
      }

      # Update running mean (Welford's online algorithm)
      for (idx in valid_idx) {
        n <- n + 1
        delta <- pixels[idx, ] - mean_acc
        mean_acc <- mean_acc + delta / n
      }

      # Clean up tile data
      rm(emb, pixels)

    }, error = function(e) {
      cli::cli_warn("Failed to process tile {i}: {e$message}")
    })

    if (progress) cli::cli_progress_update()
  }

  if (progress) cli::cli_progress_done()

  names(mean_acc) <- paste0("dim_", seq_along(mean_acc))

  list(
    mean = mean_acc,
    n_pixels = n
  )
}


#' Summarize Multiple Regions with Optimized Tile Scheduling
#'
#' Efficiently summarizes embeddings for multiple regions by:
#' 1. Building a region-to-tile mapping
#' 2. Processing tiles in an order that minimizes redundant downloads
#' 3. Computing streaming statistics for each region
#' 4. Cleaning up tiles as soon as no regions need them
#'
#' This is much more efficient than processing regions independently when
#' regions share tiles (e.g., adjacent administrative units).
#'
#' @param gt GeoTessera object
#' @param regions List of sf objects, or a single sf/sfc with multiple features
#' @param year Integer year
#' @param region_ids Optional character vector of region identifiers.
#'   If NULL, uses row indices or names from the regions.
#' @param sample_rate Fraction of pixels to sample per tile (0-1). Default 1.0.
#' @param mask_to_region If TRUE, only include pixels inside each region's
#'   polygon. Default TRUE.
#' @param seed Random seed for reproducible sampling
#' @param progress Show progress. Default TRUE.
#' @return Named list with:
#'   \itemize{
#'     \item summaries: Named list of mean embeddings per region
#'     \item pixel_counts: Named vector of pixel counts per region
#'     \item metadata: Processing statistics
#'   }
#' @export
#' @examples
#' \dontrun{
#' library(sf)
#' gt <- geotessera()
#'
#' # Load LGAs for a state
#' lgas <- st_read("nigeria_lgas.shp")
#' state_lgas <- lgas[lgas$state == "Abia", ]
#'
#' # Summarize all LGAs efficiently
#' result <- summarize_regions_streaming(
#'   gt = gt,
#'   regions = state_lgas,
#'   year = 2024,
#'   region_ids = state_lgas$adminName,
#'   sample_rate = 0.1
#' )
#'
#' # Access results
#' result$summaries[["Aba North"]]
#' }
summarize_regions_streaming <- function(gt, regions, year, region_ids = NULL,
                                         sample_rate = 1.0, mask_to_region = TRUE,
                                         seed = NULL, progress = TRUE) {
  start_time <- Sys.time()
  if (!is.null(seed)) set.seed(seed)


  # Convert to list of sf objects if needed
  if (inherits(regions, "sf") || inherits(regions, "sfc")) {
    n_regions <- nrow(regions)
    regions_list <- lapply(seq_len(n_regions), function(i) regions[i, ])
  } else if (is.list(regions)) {
    regions_list <- regions
    n_regions <- length(regions_list)
  } else {
    cli::cli_abort("regions must be an sf object or list of sf objects
")
  }

  # Set region IDs
  if (is.null(region_ids)) {
    region_ids <- paste0("region_", seq_len(n_regions))
  }
  names(regions_list) <- region_ids

  if (progress) {
    cli::cli_alert_info("Building region-to-tile mapping for {n_regions} regions...")
  }

  # Step 1: Build region-to-tile mapping
  region_tiles <- list()  # region_id -> list of tile keys
  tile_regions <- list()  # tile_key -> list of region_ids
  all_tiles_df <- NULL

  for (i in seq_len(n_regions)) {
    region_id <- region_ids[i]
    region <- regions_list[[i]]
    bbox <- sf::st_bbox(region)

    # Get tiles for this region
    tiles_df <- gt$get_tiles(bbox, year, progress = FALSE)

    if (nrow(tiles_df) > 0) {
      # Create tile keys
      tile_keys <- sprintf("%.2f_%.2f", tiles_df$lon, tiles_df$lat)
      region_tiles[[region_id]] <- tile_keys

      # Update tile -> regions mapping
      for (j in seq_along(tile_keys)) {
        key <- tile_keys[j]
        if (is.null(tile_regions[[key]])) {
          tile_regions[[key]] <- list(region_ids = character(0), tile_info = tiles_df[j, ])
        }
        tile_regions[[key]]$region_ids <- c(tile_regions[[key]]$region_ids, region_id)
      }
    } else {
      region_tiles[[region_id]] <- character(0)
    }
  }

  n_unique_tiles <- length(tile_regions)

  if (progress) {
    cli::cli_alert_info("Found {n_unique_tiles} unique tiles across all regions")

    # Calculate sharing statistics
    tiles_per_region <- sapply(region_tiles, length)
    regions_per_tile <- sapply(tile_regions, function(x) length(x$region_ids))
    shared_tiles <- sum(regions_per_tile > 1)

    if (shared_tiles > 0) {
      cli::cli_alert_success("{shared_tiles} tiles shared between regions - optimizing download order")
    }
  }

  # Step 2: Initialize streaming statistics for each region
  region_stats <- list()
  for (region_id in region_ids) {
    region_stats[[region_id]] <- list(
      n = 0,
      mean = rep(0, EMBEDDING_CHANNELS),
      tiles_remaining = length(region_tiles[[region_id]])
    )
  }

  # Step 3: Create tile processing order (greedy: most-shared tiles first)
  tile_order <- names(tile_regions)[order(
    sapply(tile_regions, function(x) length(x$region_ids)),
    decreasing = TRUE
  )]

  # Step 4: Process tiles
  if (progress) {
    cli::cli_progress_bar("Processing tiles", total = n_unique_tiles)
  }

  tiles_downloaded <- 0
  tiles_cleaned <- 0

  for (tile_key in tile_order) {
    tile_data <- tile_regions[[tile_key]]
    tile_info <- tile_data$tile_info
    affected_regions <- tile_data$region_ids

    # Download tile
    tryCatch({
      tile <- gt$download_tile(
        tile_info$lon, tile_info$lat, year,
        progress = FALSE
      )
      tiles_downloaded <- tiles_downloaded + 1

      # Load embedding once
      emb <- tile$load_embedding()
      dims <- dim(emb)

      # Get tile bounds for coordinate calculations
      bounds <- tile$get_bounds()
      x_coords <- seq(bounds$xmin, bounds$xmax, length.out = dims[2])
      y_coords <- seq(bounds$ymax, bounds$ymin, length.out = dims[1])

      # Reshape to pixels matrix
      pixels <- matrix(emb, nrow = dims[1] * dims[2], ncol = dims[3])

      # Create coordinate grid once
      coord_grid <- NULL
      if (mask_to_region) {
        coord_grid <- expand.grid(x = x_coords, y = y_coords)
      }

      # Process each region that needs this tile
      for (region_id in affected_regions) {
        region <- regions_list[[region_id]]
        stats <- region_stats[[region_id]]

        # Determine which pixels to use
        if (mask_to_region) {
          # Check which pixels are inside this region's polygon
          pts <- sf::st_as_sf(coord_grid, coords = c("x", "y"), crs = 4326)
          inside <- lengths(sf::st_intersects(pts, sf::st_geometry(region))) > 0
          valid_idx <- which(inside & complete.cases(pixels))
        } else {
          valid_idx <- which(complete.cases(pixels))
        }

        # Sample if requested
        if (sample_rate < 1.0 && length(valid_idx) > 0) {
          n_sample <- max(1, floor(length(valid_idx) * sample_rate))
          valid_idx <- sample(valid_idx, n_sample)
        }

        # Update running mean (Welford's online algorithm)
        for (idx in valid_idx) {
          stats$n <- stats$n + 1
          delta <- pixels[idx, ] - stats$mean
          stats$mean <- stats$mean + delta / stats$n
        }

        # Decrement tiles remaining for this region
        stats$tiles_remaining <- stats$tiles_remaining - 1

        # Save updated stats
        region_stats[[region_id]] <- stats
      }

      # Clean up tile data
      rm(emb, pixels)

    }, error = function(e) {
      cli::cli_warn("Failed to process tile {tile_key}: {e$message}")
    })

    # Note: With streaming, we don't need to explicitly delete tiles
    # as they go out of scope. The tile files in temp dir will be
    # cleaned up by the OS or can be explicitly managed.
    tiles_cleaned <- tiles_cleaned + 1

    if (progress) cli::cli_progress_update()
  }

  if (progress) cli::cli_progress_done()

  # Step 5: Compile results
  summaries <- list()
  pixel_counts <- numeric(n_regions)
  names(pixel_counts) <- region_ids

  for (region_id in region_ids) {
    stats <- region_stats[[region_id]]
    names(stats$mean) <- paste0("dim_", seq_along(stats$mean))
    summaries[[region_id]] <- stats$mean
    pixel_counts[region_id] <- stats$n
  }

  end_time <- Sys.time()

  if (progress) {
    cli::cli_alert_success(
      "Processed {n_regions} regions using {tiles_downloaded} tile downloads in {round(as.numeric(difftime(end_time, start_time, units = 'secs')), 1)}s"
    )
  }

  list(
    summaries = summaries,
    pixel_counts = pixel_counts,
    metadata = list(
      n_regions = n_regions,
      n_unique_tiles = n_unique_tiles,
      tiles_downloaded = tiles_downloaded,
      year = year,
      sample_rate = sample_rate,
      is_masked = mask_to_region,
      processing_time_secs = as.numeric(difftime(end_time, start_time, units = "secs"))
    )
  )
}


# Masked summary helpers ----------------------------------------------------

#' Apply Spatial Mask to Embeddings
#'
#' Masks embeddings to only include pixels within a spatial region.
#' Useful for irregular regions from shapefiles.
#'
#' @param embeddings List of 3D arrays from tiles
#' @param tiles List of Tile objects
#' @param region sf object defining the mask region
#' @return List of masked 3D arrays (pixels outside region set to NA)
#' @keywords internal
mask_embeddings_to_region <- function(embeddings, tiles, region) {
  if (!inherits(region, "sf") && !inherits(region, "sfc")) {
    # No masking needed for bbox

return(embeddings)
  }

  masked <- lapply(seq_along(embeddings), function(i) {
    emb <- embeddings[[i]]
    tile <- tiles[[i]]
    dims <- dim(emb)

    # Get tile bounds
    bounds <- tile$get_bounds()

    # Create raster-like coordinates for each pixel
    x_coords <- seq(bounds$xmin, bounds$xmax, length.out = dims[2])
    y_coords <- seq(bounds$ymax, bounds$ymin, length.out = dims[1])  # top to bottom

    # Create points for all pixels
    coords <- expand.grid(x = x_coords, y = y_coords)
    pts <- sf::st_as_sf(coords, coords = c("x", "y"), crs = 4326)

    # Check which points intersect with region
    region_transformed <- sf::st_transform(region, 4326)
    intersects <- as.vector(sf::st_intersects(pts, region_transformed, sparse = FALSE))

    # Apply mask
    mask_matrix <- matrix(!intersects, nrow = dims[1], ncol = dims[2], byrow = TRUE)

    for (ch in seq_len(dims[3])) {
      emb[, , ch][mask_matrix] <- NA
    }

    emb
  })

  masked
}
