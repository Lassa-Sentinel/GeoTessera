# Apply Spatial Mask to Embeddings

Masks embeddings to only include pixels within a spatial region. Useful
for irregular regions from shapefiles.

## Usage

``` r
mask_embeddings_to_region(embeddings, tiles, region)
```

## Arguments

- embeddings:

  List of 3D arrays from tiles

- tiles:

  List of Tile objects

- region:

  sf object defining the mask region

## Value

List of masked 3D arrays (pixels outside region set to NA)
