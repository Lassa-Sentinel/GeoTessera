# Create RGB mosaic from GeoTIFFs

Create an RGB visualization from embedding bands.

## Usage

``` r
create_rgb_mosaic(
  geotiff_paths,
  output_path,
  bands = c(30, 60, 90),
  normalize = TRUE
)
```

## Arguments

- geotiff_paths:

  Character vector of GeoTIFF paths

- output_path:

  Output file path

- bands:

  Bands to use for R, G, B (default c(30, 60, 90))

- normalize:

  Normalize values to 0-255

## Value

Output file path
