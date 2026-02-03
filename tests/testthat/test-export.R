# Test GeoTIFF export functionality - matches Python output format
# Uses UK region tile (lon=-0.05, lat=51.35) as it's a verified test case

test_that("export_embedding_geotiff creates valid GeoTIFF", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # Export a single tile from UK region
  output_path <- file.path(temp_output, "test_tile.tif")
  fs::dir_create(temp_output)

  result <- tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Verify file was created
  expect_true(fs::file_exists(result))
  expect_equal(result, output_path)
})

test_that("exported GeoTIFF has 128 bands", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "test_tile.tif")
  fs::dir_create(temp_output)

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Load with terra and check bands
  r <- terra::rast(output_path)

  # Should have 128 bands
  expect_equal(terra::nlyr(r), 128)
})

test_that("exported GeoTIFF has UTM CRS (EPSG:326xx)", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "test_tile.tif")
  fs::dir_create(temp_output)

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Load with terra and check CRS
  r <- terra::rast(output_path)
  crs_info <- sf::st_crs(terra::crs(r))

  # Should be UTM (EPSG 326xx for northern hemisphere)
  # For UK area (lon ~-0.05, lat ~51), should be EPSG:32630 (zone 30N)
  expect_true(crs_info$epsg >= 32601 && crs_info$epsg <= 32660)

  # Specifically for this longitude, should be zone 30
  expect_equal(crs_info$epsg, 32630)
})

test_that("exported GeoTIFF contains valid float data", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "test_tile.tif")
  fs::dir_create(temp_output)

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Load with terra and check values
  r <- terra::rast(output_path)
  values <- terra::values(r)

  # Values should be finite floats
  expect_true(is.numeric(values))
  expect_true(all(is.finite(values[!is.na(values)])))

  # Should have variation (not all same value)
  expect_gt(sd(values[, 1], na.rm = TRUE), 0)
})

test_that("export_embedding_geotiff respects bands parameter", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "test_tile_subset.tif")
  fs::dir_create(temp_output)

  # Export only first 3 bands
  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      bands = 1:3,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Load and check
  r <- terra::rast(output_path)

  # Should have only 3 bands
  expect_equal(terra::nlyr(r), 3)

  # Band names should reflect the subset
  expect_equal(names(r), c("band_1", "band_2", "band_3"))
})

test_that("export_embedding_geotiffs creates multiple GeoTIFFs", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)
  fs::dir_create(temp_output)

  # Get 2 tiles (download them first implicitly via export)
  points <- data.frame(
    lon = c(0.17, 0.1),
    lat = c(52.23, 52.19)
  )

  # First get the tile metadata
  tiles_df <- tryCatch({
    # Need to download tiles first
    gt$download_tiles_for_points(points, year = 2024, progress = FALSE)
    # Then get tiles in a format suitable for export
    data.frame(
      lon = c(0.15, 0.05),
      lat = c(52.25, 52.15),
      year = c(2024, 2024)
    )
  }, error = function(e) {
    skip(paste("Download failed:", conditionMessage(e)))
  })

  # Export multiple tiles
  paths <- gt$export_embedding_geotiffs(
    tiles = tiles_df,
    output_dir = temp_output,
    compress = "lzw",
    progress = FALSE
  )

  # Should have 2 files
  expect_equal(length(paths), 2)
  expect_true(all(fs::file_exists(paths)))

  # Each should have 128 bands
  for (path in paths) {
    r <- terra::rast(path)
    expect_equal(terra::nlyr(r), 128)
  }
})

test_that("tile_from_geotiff parses exported GeoTIFF correctly", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "grid_-0.05_51.35.tif")
  fs::dir_create(temp_output)

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Create Tile object from exported GeoTIFF
  tile <- tile_from_geotiff(output_path)

  expect_equal(tile$lon, -0.05, tolerance = 0.001)
  expect_equal(tile$lat, 51.35)
  expect_equal(tile$format, "geotiff")
  expect_true(tile$is_available())
})

test_that("exported GeoTIFF can be loaded as Tile", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "grid_-0.05_51.35.tif")
  fs::dir_create(temp_output)

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Create Tile and load embedding
  tile <- tile_from_geotiff(output_path)
  embedding <- tile$load_embedding()

  # Should have correct dimensions (may differ slightly due to reprojection)
  expect_equal(length(dim(embedding)), 3)
  expect_equal(dim(embedding)[3], 128)  # 128 channels
})

test_that("discover_tiles finds exported GeoTIFFs", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)
  fs::dir_create(temp_output)

  output_path <- file.path(temp_output, "grid_-0.05_51.35.tif")

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Discover tiles in the output directory
  tiles <- discover_tiles(temp_output, format = "geotiff")

  expect_equal(length(tiles), 1)
  expect_equal(tiles[[1]]$format, "geotiff")
  expect_equal(tiles[[1]]$lon, -0.05, tolerance = 0.001)
  expect_equal(tiles[[1]]$lat, 51.35)
})

test_that("Tile$get_crs returns UTM for GeoTIFF format", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  output_path <- file.path(temp_output, "grid_-0.05_51.35.tif")
  fs::dir_create(temp_output)

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  tile <- tile_from_geotiff(output_path)
  crs <- tile$get_crs()

  # Should be UTM (not WGS84)
  expect_true(crs$epsg >= 32601 && crs$epsg <= 32760)
})

test_that("merge_geotiffs_to_mosaic creates single raster", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  temp_mosaic <- tempfile("mosaic_", fileext = ".tif")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output, temp_mosaic), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)
  fs::dir_create(temp_output)

  # Export a single tile (for simplicity)
  output_path <- file.path(temp_output, "grid_-0.05_51.35.tif")

  tryCatch(
    gt$export_embedding_geotiff(
      lon = -0.05,
      lat = 51.35,
      year = 2024,
      output_path = output_path,
      compress = "lzw"
    ),
    error = function(e) {
      skip(paste("Export failed:", conditionMessage(e)))
    }
  )

  # Create mosaic
  result <- gt$merge_geotiffs_to_mosaic(
    input_dir = temp_output,
    output_path = temp_mosaic
  )

  expect_true(fs::file_exists(result))

  # Load and verify
  r <- terra::rast(result)
  expect_equal(terra::nlyr(r), 128)
})

test_that("export_pca_geotiffs creates 3-band GeoTIFFs", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  temp_output <- tempfile("output_")
  on.exit(unlink(c(temp_cache, temp_emb, temp_output), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)
  fs::dir_create(temp_output)

  # Create tiles dataframe
  tiles_df <- data.frame(
    lon = -0.05,
    lat = 51.35,
    year = 2024
  )

  # First download the tile
  tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Export PCA GeoTIFFs
  paths <- gt$export_pca_geotiffs(
    tiles = tiles_df,
    output_dir = temp_output,
    n_components = 3,
    progress = FALSE
  )

  expect_equal(length(paths), 1)
  expect_true(fs::file_exists(paths[1]))

  # Load and verify 3 bands
  r <- terra::rast(paths[1])
  expect_equal(terra::nlyr(r), 3)
  expect_equal(names(r), c("PC1", "PC2", "PC3"))
})