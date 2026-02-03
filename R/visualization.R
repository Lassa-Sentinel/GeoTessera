#' @title Visualization Functions
#' @description Functions for visualizing GeoTessera embeddings and coverage.
#' @name visualization
#' @importFrom stats na.omit complete.cases prcomp predict sd median quantile
NULL

# Declare global variables used in ggplot2 aes() to avoid R CMD check notes
utils::globalVariables(c("x", "y", "value"))

#' Analyze GeoTIFF coverage
#'
#' Analyze a collection of GeoTIFF files and return coverage statistics.
#'
#' @param geotiff_paths Character vector of paths to GeoTIFF files
#' @return Named list with coverage statistics
#' @export
analyze_geotiff_coverage <- function(geotiff_paths) {
  if (length(geotiff_paths) == 0) {
    return(list(
      n_tiles = 0,
      total_area_km2 = 0,
      bbox = NULL,
      years = integer()
    ))
  }

  # Read extents
  extents <- lapply(geotiff_paths, function(path) {
    r <- terra::rast(path)
    ext <- terra::ext(r)
    crs <- terra::crs(r)

    # Extract year from filename
    year_match <- regmatches(path, regexec("geotessera_([0-9]{4})", path))[[1]]
    year <- if (length(year_match) > 1) as.integer(year_match[2]) else NA_integer_

    list(
      xmin = ext$xmin,
      xmax = ext$xmax,
      ymin = ext$ymin,
      ymax = ext$ymax,
      crs = as.character(crs),
      year = year
    )
  })

  # Combine extents
  all_xmin <- min(sapply(extents, `[[`, "xmin"))
  all_xmax <- max(sapply(extents, `[[`, "xmax"))
  all_ymin <- min(sapply(extents, `[[`, "ymin"))
  all_ymax <- max(sapply(extents, `[[`, "ymax"))
  years <- unique(na.omit(sapply(extents, `[[`, "year")))

  # Calculate total area (approximate)
  # Each tile is approximately 0.1 x 0.1 degrees
  # At equator, 1 degree ~ 111 km
  avg_lat <- (all_ymin + all_ymax) / 2
  km_per_deg_lon <- 111 * cos(avg_lat * pi / 180)
  km_per_deg_lat <- 111
  tile_area_km2 <- 0.1 * km_per_deg_lon * 0.1 * km_per_deg_lat
  total_area_km2 <- length(geotiff_paths) * tile_area_km2

  list(
    n_tiles = length(geotiff_paths),
    total_area_km2 = total_area_km2,
    bbox = c(xmin = all_xmin, ymin = all_ymin, xmax = all_xmax, ymax = all_ymax),
    years = sort(years)
  )
}

#' Create RGB mosaic from GeoTIFFs
#'
#' Create an RGB visualization from embedding bands.
#'
#' @param geotiff_paths Character vector of GeoTIFF paths
#' @param output_path Output file path
#' @param bands Bands to use for R, G, B (default c(30, 60, 90))
#' @param normalize Normalize values to 0-255
#' @return Output file path
#' @export
create_rgb_mosaic <- function(geotiff_paths, output_path, bands = c(30, 60, 90),
                               normalize = TRUE) {
  if (length(bands) != 3) {
    cli::cli_abort("Must specify exactly 3 bands for RGB")
  }

  # Load and merge rasters
  rasters <- lapply(geotiff_paths, function(path) {
    r <- terra::rast(path)
    terra::subset(r, bands)
  })

  if (length(rasters) == 1) {
    merged <- rasters[[1]]
  } else {
    merged <- do.call(terra::merge, rasters)
  }

  # Normalize to 0-255 if requested
  if (normalize) {
    for (i in seq_len(terra::nlyr(merged))) {
      lyr <- merged[[i]]
      min_val <- terra::minmax(lyr)[1]
      max_val <- terra::minmax(lyr)[2]
      if (max_val > min_val) {
        merged[[i]] <- 255 * (lyr - min_val) / (max_val - min_val)
      }
    }
  }

  names(merged) <- c("red", "green", "blue")
  terra::writeRaster(merged, output_path, overwrite = TRUE, datatype = "INT1U")
  output_path
}

#' Create PCA mosaic visualization
#'
#' Apply PCA across multiple tiles and create RGB visualization.
#'
#' @param geotiff_paths Character vector of GeoTIFF paths
#' @param output_path Output file path
#' @param n_components Number of PCA components (default 3 for RGB)
#' @return Output file path
#' @export
create_pca_mosaic <- function(geotiff_paths, output_path, n_components = 3) {
  # Load all rasters
  cli::cli_alert_info("Loading {length(geotiff_paths)} tiles...")

  rasters <- lapply(geotiff_paths, terra::rast)
  if (length(rasters) == 1) {
    merged <- rasters[[1]]
  } else {
    merged <- do.call(terra::merge, rasters)
  }

  # Extract values for PCA
  cli::cli_alert_info("Running PCA...")
  values <- terra::values(merged)
  valid_rows <- complete.cases(values)

  if (sum(valid_rows) < n_components) {
    cli::cli_abort("Not enough valid pixels for PCA")
  }

  # Run PCA
  pca_result <- prcomp(values[valid_rows, ], center = TRUE, scale. = TRUE,
                       rank. = n_components)

  # Project all values
  pca_scores <- matrix(NA_real_, nrow = nrow(values), ncol = n_components)
  pca_scores[valid_rows, ] <- predict(pca_result, values[valid_rows, ])

  # Create output raster
  cli::cli_alert_info("Creating output raster...")
  out_rast <- terra::rast(merged[[1:n_components]])
  terra::values(out_rast) <- pca_scores

  # Normalize to 0-255
  for (i in seq_len(n_components)) {
    lyr <- out_rast[[i]]
    min_val <- terra::minmax(lyr)[1]
    max_val <- terra::minmax(lyr)[2]
    if (max_val > min_val) {
      out_rast[[i]] <- 255 * (lyr - min_val) / (max_val - min_val)
    }
  }

  names(out_rast) <- paste0("PC", seq_len(n_components))
  terra::writeRaster(out_rast, output_path, overwrite = TRUE, datatype = "INT1U")
  output_path
}

#' Visualize global coverage
#'
#' Create a visualization of tile coverage.
#'
#' @param gt GeoTessera object
#' @param output_path Output file path (PNG)
#' @param year Year to visualize (NULL for all)
#' @param width_pixels Width in pixels
#' @param tile_color Color for tiles
#' @param tile_alpha Transparency for tiles
#' @return Output file path (invisibly)
#' @export
visualize_global_coverage <- function(gt, output_path = NULL, year = NULL,
                                       width_pixels = 2000, tile_color = "red",
                                       tile_alpha = 0.6) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package 'ggplot2' required for visualization")
  }

  # Get tile data
  tiles_df <- if (!is.null(year)) {
    gt$get_tiles(bbox = list(xmin = -180, ymin = -90, xmax = 180, ymax = 90), year = year)
  } else {
    # Get from registry
    registry <- gt$registry
    tryCatch({
      years <- registry$get_available_years()
      all_tiles <- list()
      for (y in years) {
        tiles <- gt$get_tiles(
          bbox = list(xmin = -180, ymin = -90, xmax = 180, ymax = 90),
          year = y, progress = FALSE
        )
        if (nrow(tiles) > 0) {
          all_tiles[[length(all_tiles) + 1]] <- tiles
        }
      }
      if (length(all_tiles) > 0) do.call(rbind, all_tiles) else data.frame()
    }, error = function(e) {
      data.frame()
    })
  }

  if (nrow(tiles_df) == 0) {
    cli::cli_warn("No tiles found to visualize")
    return(invisible(NULL))
  }

  # Create tile polygons
  tile_polys <- lapply(seq_len(nrow(tiles_df)), function(i) {
    bounds <- tile_to_bounds(tiles_df$lon[i], tiles_df$lat[i])
    sf::st_polygon(list(matrix(c(
      bounds$xmin, bounds$ymin,
      bounds$xmax, bounds$ymin,
      bounds$xmax, bounds$ymax,
      bounds$xmin, bounds$ymax,
      bounds$xmin, bounds$ymin
    ), ncol = 2, byrow = TRUE)))
  })

  tiles_sf <- sf::st_sf(
    geometry = sf::st_sfc(tile_polys, crs = 4326),
    lon = tiles_df$lon,
    lat = tiles_df$lat
  )

  # Create plot
  world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = world, fill = "lightgray", color = "white", linewidth = 0.1) +
    ggplot2::geom_sf(data = tiles_sf, fill = tile_color, color = NA, alpha = tile_alpha) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "GeoTessera Tile Coverage",
      subtitle = if (!is.null(year)) paste("Year:", year) else "All Years"
    )

  if (!is.null(output_path)) {
    height_pixels <- width_pixels / 2
    ggplot2::ggsave(output_path, p, width = width_pixels / 100, height = height_pixels / 100,
                    dpi = 100)
    cli::cli_alert_success("Saved coverage map to {output_path}")
    return(invisible(output_path))
  }

  p
}

#' Calculate bounding box from file
#'
#' Extract bounding box from a GeoTIFF or vector file.
#'
#' @param filepath Path to file
#' @return sf bbox object
#' @export
calculate_bbox_from_file <- function(filepath) {
  ext <- tolower(fs::path_ext(filepath))

  if (ext %in% c("tif", "tiff")) {
    r <- terra::rast(filepath)
    ext_obj <- terra::ext(r)
    sf::st_bbox(c(
      xmin = ext_obj$xmin,
      ymin = ext_obj$ymin,
      xmax = ext_obj$xmax,
      ymax = ext_obj$ymax
    ), crs = sf::st_crs(terra::crs(r)))
  } else if (ext %in% c("shp", "gpkg", "geojson", "json")) {
    sf_obj <- sf::st_read(filepath, quiet = TRUE)
    sf::st_bbox(sf_obj)
  } else {
    cli::cli_abort("Unsupported file format: {ext}")
  }
}

#' Create coverage summary
#'
#' Generate a summary of tile coverage statistics.
#'
#' @param gt GeoTessera object
#' @param output_path Optional output file for JSON summary
#' @return Named list with coverage statistics
#' @export
create_coverage_summary <- function(gt, output_path = NULL) {
  years <- gt$registry$get_available_years()
  counts <- gt$registry$get_tile_counts_by_year()

  summary_data <- list(
    version = gt$version,
    available_years = years,
    tile_counts_by_year = as.list(counts),
    total_tiles = sum(counts),
    timestamp = Sys.time()
  )

  if (!is.null(output_path)) {
    jsonlite::write_json(summary_data, output_path, auto_unbox = TRUE, pretty = TRUE)
    cli::cli_alert_success("Saved coverage summary to {output_path}")
  }

  summary_data
}

#' Plot embedding bands
#'
#' Create a visualization of selected embedding bands from a tile.
#'
#' @param tile Tile object
#' @param bands Bands to plot (default first 9)
#' @param ncol Number of columns in plot grid
#' @return ggplot object
#' @export
plot_embedding_bands <- function(tile, bands = 1:9, ncol = 3) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package 'ggplot2' required for visualization")
  }

  embedding <- tile$load_embedding()
  bounds <- tile$get_bounds()

  # Create a raster for each band
  plots <- lapply(bands, function(b) {
    if (b > dim(embedding)[3]) {
      cli::cli_warn("Band {b} exceeds available bands, skipping")
      return(NULL)
    }

    r <- terra::rast(
      nrows = dim(embedding)[1],
      ncols = dim(embedding)[2],
      xmin = bounds$xmin,
      xmax = bounds$xmax,
      ymin = bounds$ymin,
      ymax = bounds$ymax
    )
    terra::values(r) <- as.vector(t(embedding[, , b]))

    df <- as.data.frame(r, xy = TRUE)
    names(df)[3] <- "value"

    ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = value)) +
      ggplot2::geom_raster() +
      ggplot2::scale_fill_viridis_c() +
      ggplot2::coord_fixed() +
      ggplot2::labs(title = paste("Band", b)) +
      ggplot2::theme_minimal() +
      ggplot2::theme(legend.position = "none")
  })

  plots <- Filter(Negate(is.null), plots)

  if (requireNamespace("patchwork", quietly = TRUE)) {
    patchwork::wrap_plots(plots, ncol = ncol)
  } else {
    cli::cli_warn("Install 'patchwork' package for combined plot")
    plots[[1]]
  }
}
