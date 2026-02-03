# Tests for region summarization functionality

test_that("summary_mean works with mock embeddings", {
  # Create mock embeddings (2 tiles, each 10x10x128)
  set.seed(42)
  emb1 <- array(rnorm(10 * 10 * 128), dim = c(10, 10, 128))
  emb2 <- array(rnorm(10 * 10 * 128), dim = c(10, 10, 128))
  embeddings <- list(emb1, emb2)

  result <- summary_mean(embeddings)

  expect_length(result, 128)
  expect_true(all(!is.na(result)))
  expect_true(all(names(result) == paste0("dim_", 1:128)))
})

test_that("summary_median works with mock embeddings", {
  set.seed(42)
  emb1 <- array(rnorm(10 * 10 * 128), dim = c(10, 10, 128))
  embeddings <- list(emb1)

  result <- summary_median(embeddings)

  expect_length(result, 128)
  expect_true(all(!is.na(result)))
})

test_that("summary_sd works with mock embeddings", {
  set.seed(42)
  emb1 <- array(rnorm(10 * 10 * 128), dim = c(10, 10, 128))
  embeddings <- list(emb1)

  result <- summary_sd(embeddings)

  expect_length(result, 128)
  expect_true(all(result > 0))  # SD should be positive for random data
})

test_that("summary_pixel_count works correctly", {
  # Create embeddings with some NAs
  emb1 <- array(1, dim = c(10, 10, 128))
  emb1[1:3, 1:3, ] <- NA  # 9 NA pixels
  embeddings <- list(emb1)

  result <- summary_pixel_count(embeddings)

  expect_equal(unname(result["total_pixels"]), 100)
  expect_equal(unname(result["valid_pixels"]), 91)  # 100 - 9 NA pixels
})

test_that("summary_coverage returns correct statistics", {
  emb1 <- array(1, dim = c(10, 10, 128))
  emb1[1:5, , ] <- NA  # 50% NA
  embeddings <- list(emb1)

  result <- summary_coverage(embeddings)

  expect_equal(unname(result["n_tiles"]), 1)
  expect_equal(unname(result["n_total_pixels"]), 100)
  expect_equal(unname(result["n_valid_pixels"]), 50)
  expect_equal(unname(result["coverage_percent"]), 50)
})

test_that("summary_quantile factory works", {
  set.seed(42)
  emb1 <- array(rnorm(10 * 10 * 128), dim = c(10, 10, 128))
  embeddings <- list(emb1)

  q_fn <- summary_quantile(c(0.25, 0.75))
  result <- q_fn(embeddings)

  # Should have 2 quantiles per dimension
  expect_length(result, 128 * 2)
})

test_that("summary_random_sample factory works", {
  set.seed(42)
  emb1 <- array(rnorm(10 * 10 * 128), dim = c(10, 10, 128))
  embeddings <- list(emb1)

  sample_fn <- summary_random_sample(n = 5, seed = 123)
  result <- sample_fn(embeddings)

  expect_true(is.matrix(result))
  expect_equal(nrow(result), 5)
  expect_equal(ncol(result), 128)
})

test_that("summary functions handle empty/NA embeddings", {
  # All NA embedding
  emb_na <- array(NA_real_, dim = c(10, 10, 128))
  embeddings <- list(emb_na)

  result_mean <- summary_mean(embeddings)
  expect_true(all(is.na(result_mean)))

  result_median <- summary_median(embeddings)
  expect_true(all(is.na(result_median)))

  result_count <- summary_pixel_count(embeddings)
  expect_equal(unname(result_count["valid_pixels"]), 0)
})

test_that("summarize_region method exists on GeoTessera",
{
  gt <- GeoTessera$new()
  expect_true("summarize_region" %in% names(gt))
})

# Integration test with real data (skipped by default)
test_that("summarize_region works with real data", {
  skip_on_cran()
  skip_if_offline()

  gt <- GeoTessera$new()

  # Use a very small region (single tile area near Cambridge)
  bbox <- c(0.17, 52.23, 0.19, 52.25)

  # This will download real data
  result <- gt$summarize_region(
    region = bbox,
    year = 2024,
    summary_fns = list(
      mean = summary_mean,
      coverage = summary_coverage
    ),
    progress = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_true("summaries" %in% names(result))
  expect_true("metadata" %in% names(result))

  # Check summaries
  expect_true("mean" %in% names(result$summaries))
  expect_true("coverage" %in% names(result$summaries))
  expect_length(result$summaries$mean, 128)

  # Check metadata
  expect_equal(result$metadata$year, 2024)
  expect_true(result$metadata$n_tiles >= 1)
})
