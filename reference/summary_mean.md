# Mean Embedding Summary

Computes the mean embedding across all valid pixels in the region.

## Usage

``` r
summary_mean(embeddings, region = NULL, tiles_df = NULL)
```

## Arguments

- embeddings:

  List of 3D arrays (height, width, channels) from tiles

- region:

  sf object or bbox defining the region (used for masking)

- tiles_df:

  Data frame of tile metadata

## Value

Named numeric vector of length 128 (mean embedding)

## Examples

``` r
if (FALSE) { # \dontrun{
gt <- geotessera()
result <- gt$summarize_region(
  region = c(0.08, 52.18, 0.15, 52.21),
  year = 2024,
  summary_fns = list(mean = summary_mean)
)
} # }
```
