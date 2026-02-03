# Visualize global coverage

Create a visualization of tile coverage.

## Usage

``` r
visualize_global_coverage(
  gt,
  output_path = NULL,
  year = NULL,
  width_pixels = 2000,
  tile_color = "red",
  tile_alpha = 0.6
)
```

## Arguments

- gt:

  GeoTessera object

- output_path:

  Output file path (PNG)

- year:

  Year to visualize (NULL for all)

- width_pixels:

  Width in pixels

- tile_color:

  Color for tiles

- tile_alpha:

  Transparency for tiles

## Value

Output file path (invisibly)
