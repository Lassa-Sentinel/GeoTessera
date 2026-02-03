# Centroid Embedding Summary

Samples the embedding at the geographic centroid of the region.

## Usage

``` r
summary_centroid(
  embeddings,
  region = NULL,
  tiles_df = NULL,
  gt = NULL,
  year = NULL
)
```

## Arguments

- embeddings:

  List of 3D arrays (height, width, channels) from tiles

- region:

  sf object or bbox defining the region (used for masking)

- tiles_df:

  Data frame of tile metadata

- gt:

  GeoTessera object (passed automatically by summarize_region)

- year:

  Integer year (passed automatically by summarize_region)

## Value

Named numeric vector of length 128 (centroid embedding)
