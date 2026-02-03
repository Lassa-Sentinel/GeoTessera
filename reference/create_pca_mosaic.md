# Create PCA mosaic visualization

Apply PCA across multiple tiles and create RGB visualization.

## Usage

``` r
create_pca_mosaic(geotiff_paths, output_path, n_components = 3)
```

## Arguments

- geotiff_paths:

  Character vector of GeoTIFF paths

- output_path:

  Output file path

- n_components:

  Number of PCA components (default 3 for RGB)

## Value

Output file path
