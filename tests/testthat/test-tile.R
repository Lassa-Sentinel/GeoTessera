# Test Tile class with both unit tests and real data tests

test_that("Tile object is created correctly", {
  tile <- Tile$new(
    lon = 0.15,
    lat = 51.55,
    year = 2024,
    format = "npy"
  )

  expect_equal(tile$lon, 0.15)
  expect_equal(tile$lat, 51.55)
  expect_equal(tile$year, 2024)
  expect_equal(tile$format, "npy")
})

test_that("Tile grid name is generated correctly", {
  tile <- Tile$new(lon = 0.15, lat = 51.55, year = 2024)

  expect_equal(tile$get_grid_name(), "grid_0.15_51.55")
})

test_that("Tile bounds are calculated correctly", {
  tile <- Tile$new(lon = 0.15, lat = 51.55, year = 2024)

  bounds <- tile$get_bounds()

  expect_equal(bounds$xmin, 0.10)
  expect_equal(bounds$xmax, 0.20)
  expect_equal(bounds$ymin, 51.50)
  expect_equal(bounds$ymax, 51.60)
})

test_that("Tile dimensions are correct", {
  tile <- Tile$new(lon = 0.15, lat = 51.55, year = 2024)

  dims <- tile$get_dimensions()

  expect_equal(dims$height, 1111)
  expect_equal(dims$width, 1111)
  expect_equal(dims$channels, 128)
})

test_that("Tile contains_point works correctly", {
  tile <- Tile$new(lon = 0.15, lat = 51.55, year = 2024)

  # Point inside
  expect_true(tile$contains_point(0.15, 51.55))
  expect_true(tile$contains_point(0.11, 51.51))
  expect_true(tile$contains_point(0.19, 51.59))

  # Point outside
  expect_false(tile$contains_point(0.25, 51.55))  # East
  expect_false(tile$contains_point(0.05, 51.55))  # West
  expect_false(tile$contains_point(0.15, 51.65))  # North
  expect_false(tile$contains_point(0.15, 51.45))  # South
})

test_that("Tile is_available returns false when no path set", {
  tile <- Tile$new(lon = 0.15, lat = 51.55, year = 2024, format = "npy")

  expect_false(tile$is_available())
})

test_that("Tile to_list returns correct structure", {
  tile <- Tile$new(
    lon = 0.15,
    lat = 51.55,
    year = 2024,
    format = "npy",
    path = "/path/to/embedding.npy",
    scales_path = "/path/to/scales.npy"
  )

  result <- tile$to_list()

  expect_equal(result$lon, 0.15)
  expect_equal(result$lat, 51.55)
  expect_equal(result$year, 2024)
  expect_equal(result$grid_name, "grid_0.15_51.55")
  expect_equal(result$format, "npy")
  expect_equal(result$path, "/path/to/embedding.npy")
  expect_equal(result$scales_path, "/path/to/scales.npy")
})

test_that("discover_tiles returns empty list for empty directory", {
  temp_dir <- tempdir()
  empty_dir <- file.path(temp_dir, "empty_test")
  dir.create(empty_dir, showWarnings = FALSE)
  on.exit(unlink(empty_dir, recursive = TRUE))

  tiles <- discover_tiles(empty_dir)
  expect_equal(length(tiles), 0)
})

test_that("discover_tiles errors on non-existent directory", {
  expect_error(discover_tiles("/nonexistent/path"))
})

# Real data tests for Tile class

test_that("Tile$load_embedding returns correct dimensions", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # Download a tile from UK region
  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  embedding <- tile$load_embedding()

  # Verify dimensions: (height, width, channels)
  # Note: height and width vary by latitude, but channels is always 128
  expect_equal(length(dim(embedding)), 3)
  expect_gt(dim(embedding)[1], 500)  # reasonable height
  expect_gt(dim(embedding)[2], 500)  # reasonable width
  expect_equal(dim(embedding)[3], 128)
})

test_that("Tile$load_embedding performs dequantization correctly", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  embedding <- tile$load_embedding()

  # Dequantized values should be floats
  expect_type(embedding, "double")

  # Values should not be exactly integers (they would be if not dequantized)
  # Get a sample of values
  sample_vals <- embedding[500:510, 500:510, 1]
  non_integer <- any(sample_vals != floor(sample_vals))
  expect_true(non_integer)

  # Values should be in reasonable range
  expect_true(all(is.finite(embedding)))
})

test_that("Tile$sample_at_point returns 128-element vector", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Sample at a point within the tile
  sample <- tile$sample_at_point(-0.05, 51.35)

  expect_equal(length(sample), 128)
  expect_type(sample, "double")
  expect_true(all(is.finite(sample)))
})

test_that("Tile$sample_at_point errors for points outside tile", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Tile is grid_-0.05_51.35, bounds are (-0.10, 51.30) to (0.00, 51.40)
  # Point outside should error
  expect_error(tile$sample_at_point(-0.15, 51.35))  # West of tile
  expect_error(tile$sample_at_point(0.05, 51.35))   # East of tile
  expect_error(tile$sample_at_point(-0.05, 51.25))  # South of tile
  expect_error(tile$sample_at_point(-0.05, 51.45))  # North of tile
})

test_that("discover_tiles finds downloaded NPY tiles", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # Download a tile
  tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Discover tiles
  tiles <- discover_tiles(temp_emb)

  expect_equal(length(tiles), 1)
  expect_equal(tiles[[1]]$format, "npy")
  expect_equal(tiles[[1]]$lon, -0.05, tolerance = 0.001)
  expect_equal(tiles[[1]]$lat, 51.35)
  expect_true(tiles[[1]]$is_available())
})

test_that("discover_tiles finds multiple tiles", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # Download 2 tiles
  points <- data.frame(
    lon = c(0.17, 0.1),
    lat = c(52.23, 52.19)
  )

  tryCatch(
    gt$download_tiles_for_points(points, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Discover tiles
  tiles <- discover_tiles(temp_emb)

  expect_equal(length(tiles), 2)
  expect_true(all(sapply(tiles, function(t) t$format == "npy")))
  expect_true(all(sapply(tiles, function(t) t$is_available())))
})

test_that("tile_from_npy creates correct Tile object", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  downloaded_tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Create tile from NPY file path
  created_tile <- tile_from_npy(downloaded_tile$path, temp_emb)

  expect_equal(created_tile$lon, -0.05, tolerance = 0.001)
  expect_equal(created_tile$lat, 51.35)
  expect_equal(created_tile$year, 2024)
  expect_equal(created_tile$format, "npy")
  expect_true(created_tile$is_available())

  # Verify can load embedding
  # Note: dimensions vary by latitude, but should have 128 channels
  embedding <- created_tile$load_embedding()
  expect_equal(length(dim(embedding)), 3)
  expect_equal(dim(embedding)[3], 128)
})

test_that("Tile$get_crs returns WGS84 for NPY format", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  crs <- tile$get_crs()

  # NPY format uses WGS84 (EPSG:4326)
  expect_true(sf::st_crs(crs)$epsg == 4326 || grepl("WGS 84", crs$wkt, ignore.case = TRUE))
})

test_that("Tile$get_transform returns correct values for NPY", {
  tile <- Tile$new(lon = -0.05, lat = 51.35, year = 2024, format = "npy")

  transform <- tile$get_transform()

  # Verify transform structure
  expect_true("xres" %in% names(transform))
  expect_true("yres" %in% names(transform))
  expect_true("xmin" %in% names(transform))
  expect_true("ymax" %in% names(transform))

  # Verify values are consistent with tile size
  # Tile is 0.1 degrees / 1111 pixels
  expected_res <- 0.1 / 1111
  expect_equal(transform$xres, expected_res, tolerance = 0.001)
  expect_equal(transform$yres, expected_res, tolerance = 0.001)

  # Verify origin matches tile bounds
  expect_equal(transform$xmin, -0.10)
  expect_equal(transform$ymax, 51.40)
})
