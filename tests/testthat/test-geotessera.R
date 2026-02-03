test_that("GeoTessera object is created correctly", {
  skip_on_cran()

  gt <- GeoTessera$new()

  expect_equal(gt$version, "v1")
  expect_s3_class(gt$registry, "Registry")
})

test_that("geotessera convenience function creates GeoTessera object", {
  skip_on_cran()

  gt <- geotessera()

  expect_s3_class(gt, "GeoTessera")
  expect_equal(gt$version, "v1")
})

test_that("GeoTessera accepts custom parameters", {
  skip_on_cran()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")

  gt <- GeoTessera$new(
    dataset_version = "v2",
    cache_dir = temp_cache,
    embeddings_dir = temp_emb,
    verify_hashes = FALSE
  )

  expect_equal(gt$version, "v2")
  expect_equal(gt$registry$cache_dir, temp_cache)
  expect_equal(gt$registry$embeddings_dir, temp_emb)

  unlink(c(temp_cache, temp_emb), recursive = TRUE)
})

test_that("embeddings_count delegates to registry", {
  skip_on_cran()
  skip_if_offline()

  # Use a fresh temp cache to avoid corrupted cached files
  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  gt <- geotessera(cache_dir = temp_cache)
  bbox <- list(xmin = 0, ymin = 51, xmax = 0.5, ymax = 51.5)

  # Skip if registry download fails (network issues, server issues)
  count <- tryCatch(
    gt$embeddings_count(bbox, 2024),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  expect_type(count, "integer")
  expect_gte(count, 0)
})

test_that("check_tiles_present returns correct structure", {
  skip_on_cran()

  gt <- geotessera()
  points <- data.frame(
    lon = c(0.15, 0.25),
    lat = c(51.55, 51.65)
  )

  result <- gt$check_tiles_present(points, 2024)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("lon" %in% names(result))
  expect_true("lat" %in% names(result))
  expect_true("tile_lon" %in% names(result))
  expect_true("tile_lat" %in% names(result))
  expect_true("available" %in% names(result))
})

test_that("export_coverage_map returns correct structure", {
  skip_on_cran()
  skip_if_offline()

  # Use a fresh temp cache
  temp_cache <- tempfile("cache_")
  on.exit(unlink(temp_cache, recursive = TRUE))

  gt <- geotessera(cache_dir = temp_cache)

  # Skip if registry download fails
  coverage <- tryCatch(
    gt$export_coverage_map(),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  expect_type(coverage, "list")
  expect_true("version" %in% names(coverage))
  expect_true("available_years" %in% names(coverage))
  expect_true("total_tiles" %in% names(coverage))
})

test_that("apply_pca_to_embeddings works with 2D input", {
  skip_on_cran()

  gt <- geotessera()

  # Create test data
  set.seed(42)
  data <- matrix(rnorm(1000 * 128), nrow = 1000, ncol = 128)

  result <- gt$apply_pca_to_embeddings(data, n_components = 3)

  expect_equal(dim(result), c(1000, 3))
})

test_that("apply_pca_to_embeddings works with 3D input", {
  skip_on_cran()

  gt <- geotessera()

  # Create test data
  set.seed(42)
  data <- array(rnorm(100 * 100 * 128), dim = c(100, 100, 128))

  result <- gt$apply_pca_to_embeddings(data, n_components = 3)

  expect_equal(dim(result), c(100, 100, 3))
})
