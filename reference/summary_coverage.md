# Coverage Statistics Summary

Returns coverage statistics for the region including tile count and
area.

## Usage

``` r
summary_coverage(embeddings, region = NULL, tiles_df = NULL)
```

## Arguments

- embeddings:

  List of 3D arrays (height, width, channels) from tiles

- region:

  sf object or bbox defining the region (used for masking)

- tiles_df:

  Data frame of tile metadata

## Value

Named vector with coverage statistics
