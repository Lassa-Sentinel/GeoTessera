# Test Registry class with real data - tests match Python CRAM test expectations

test_that("Registry object is created with defaults", {
  skip_on_cran()

  registry <- Registry$new()

  expect_equal(registry$version, "v1")
  expect_true(registry$verify_hashes)
  expect_true(fs::dir_exists(registry$cache_dir))
})

test_that("Registry object accepts custom parameters", {
  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")

  registry <- Registry$new(
    version = "v2",
    cache_dir = temp_cache,
    embeddings_dir = temp_emb,
    verify_hashes = FALSE
  )

  expect_equal(registry$version, "v2")
  expect_equal(registry$cache_dir, temp_cache)
  expect_equal(registry$embeddings_dir, temp_emb)
  expect_false(registry$verify_hashes)

  # Cleanup
  unlink(c(temp_cache, temp_emb), recursive = TRUE)
})

test_that("Registry URL is constructed correctly", {
  registry <- Registry$new(version = "v1")

  expect_match(registry$registry_url, "dl2.geotessera.org")
  expect_match(registry$registry_url, "v1")
})

test_that("embeddings_count returns integer", {
  skip_on_cran()
  skip_if_offline()

  # Use a fresh temp cache to avoid corrupted cached files
  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)
  bbox <- list(xmin = -0.01, ymin = 51.5, xmax = 0.01, ymax = 51.51)

  # Skip if registry download fails (network issues, server issues)
  count <- tryCatch(
    registry$embeddings_count(bbox, 2024),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  expect_type(count, "integer")
  expect_gte(count, 0)
})

# Real data tests matching Python CRAM tests

test_that("load_tiles_for_region returns 16 tiles for UK bbox", {
  skip_on_cran()
  skip_if_offline()

  # From Python CRAM test: bbox "-0.1,51.3,0.1,51.5" produces 16 tiles
  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # UK bbox from Python tests
  bbox <- list(xmin = -0.1, ymin = 51.3, xmax = 0.1, ymax = 51.5)

  tiles <- tryCatch(
    registry$load_tiles_for_region(bbox, 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Should return exactly 16 tiles (4x4 grid) as per Python test
  expect_equal(nrow(tiles), 16)

  # Verify tile columns exist
  expect_true("lon" %in% names(tiles))
  expect_true("lat" %in% names(tiles))
  expect_true("year" %in% names(tiles))

  # Verify all tiles are for year 2024
  expect_true(all(tiles$year == 2024))
})

test_that("load_tiles_for_region returns 4 tiles for Cambridge bbox", {
  skip_on_cran()
  skip_if_offline()

  # From Python CRAM test: Cambridge bbox produces 4 tiles
  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # Cambridge bbox from Python tests
  bbox <- list(xmin = 0.086174, ymin = 52.183432, xmax = 0.151062, ymax = 52.206318)

  tiles <- tryCatch(
    registry$load_tiles_for_region(bbox, 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Should return exactly 4 tiles (2x2 grid) as per Python test
  expect_equal(nrow(tiles), 4)

  # Verify expected tile coordinates
  # grid_0.05_52.15, grid_0.05_52.25, grid_0.15_52.15, grid_0.15_52.25
  expected_lons <- c(0.05, 0.15)
  expected_lats <- c(52.15, 52.25)

  unique_lons <- sort(unique(tiles$lon))
  unique_lats <- sort(unique(tiles$lat))

  expect_equal(unique_lons, expected_lons)
  expect_equal(unique_lats, expected_lats)
})

test_that("embeddings_count matches Python for UK bbox", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # UK bbox from Python tests
  bbox <- list(xmin = -0.1, ymin = 51.3, xmax = 0.1, ymax = 51.5)

  count <- tryCatch(
    registry$embeddings_count(bbox, 2024),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Should return 16 tiles
  expect_equal(count, 16L)
})

test_that("embeddings_count matches Python for Cambridge bbox", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # Cambridge bbox from Python tests
  bbox <- list(xmin = 0.086174, ymin = 52.183432, xmax = 0.151062, ymax = 52.206318)

  count <- tryCatch(
    registry$embeddings_count(bbox, 2024),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Should return 4 tiles
  expect_equal(count, 4L)
})

test_that("embeddings_count returns 1 for single tile bbox", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # Very small bbox that should contain only 1 tile
  # From Python hash test: bbox "0.18952,52.18602,0.18953,52.18603"
  bbox <- list(xmin = 0.18952, ymin = 52.18602, xmax = 0.18953, ymax = 52.18603)

  count <- tryCatch(
    registry$embeddings_count(bbox, 2024),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Should return 1 tile
  expect_equal(count, 1L)
})

test_that("load_tiles_for_region returns tile metadata with expected columns", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # Small bbox to get just 1 tile
  bbox <- list(xmin = 0.18952, ymin = 52.18602, xmax = 0.18953, ymax = 52.18603)

  tiles <- tryCatch(
    registry$load_tiles_for_region(bbox, 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Verify expected columns from Python registry
  expect_true("lon" %in% names(tiles))
  expect_true("lat" %in% names(tiles))
  expect_true("embedding_hash" %in% names(tiles))
  expect_true("scales_hash" %in% names(tiles))
  expect_true("embedding_size" %in% names(tiles))
  expect_true("scales_size" %in% names(tiles))

  # Verify hash values are non-empty strings
  expect_true(nchar(tiles$embedding_hash[1]) > 0)
  expect_true(nchar(tiles$scales_hash[1]) > 0)

  # Verify sizes are positive integers
  expect_gt(tiles$embedding_size[1], 0)
  expect_gt(tiles$scales_size[1], 0)
})

test_that("calculate_download_requirements returns correct structure", {
  skip_on_cran()

  registry <- Registry$new()
  tiles <- data.frame(
    lon = c(0.15, 0.25),
    lat = c(51.55, 51.55),
    year = c(2024, 2024),
    embedding_size = c(100, 200),
    scales_size = c(10, 20)
  )

  temp_dir <- tempfile("output_")
  result <- registry$calculate_download_requirements(tiles, temp_dir, "tiff")

  expect_type(result$total_size, "double")
  expect_type(result$tiles_to_download, "double")
  expect_type(result$tiles_existing, "double")
  expect_equal(result$tiles_to_download, 2)
  expect_equal(result$tiles_existing, 0)

  unlink(temp_dir, recursive = TRUE)
})

test_that("iter_tiles_in_region works correctly", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache)

  # Cambridge bbox - should have 4 tiles
  bbox <- list(xmin = 0.086174, ymin = 52.183432, xmax = 0.151062, ymax = 52.206318)

  iter <- tryCatch(
    registry$iter_tiles_in_region(bbox, 2024),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  # Collect all tiles from iterator
  tiles <- list()
  repeat {
    tile <- iter()
    if (is.null(tile)) break
    tiles[[length(tiles) + 1]] <- tile
  }

  # Should have 4 tiles
 expect_equal(length(tiles), 4)

  # Each tile should have lon and lat
  expect_true(all(sapply(tiles, function(t) !is.null(t$lon))))
  expect_true(all(sapply(tiles, function(t) !is.null(t$lat))))
})
