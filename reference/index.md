# Package index

## Main Interface

- [`geotessera()`](https://lassa-sentinel.github.io/GeoTessera/reference/GeoTessera.md)
  : GeoTessera Class

## Region Summarization

- [`summarize_regions_streaming()`](https://lassa-sentinel.github.io/GeoTessera/reference/summarize_regions_streaming.md)
  : Summarize Multiple Regions with Optimized Tile Scheduling
- [`summary_mean_streaming()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_mean_streaming.md)
  : Streaming Mean Summary (Memory Efficient)
- [`summary_centroid()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_centroid.md)
  : Centroid Embedding Summary
- [`summary_coverage()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_coverage.md)
  : Coverage Statistics Summary
- [`summary_mean()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_mean.md)
  : Mean Embedding Summary
- [`summary_median()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_median.md)
  : Median Embedding Summary
- [`summary_pixel_count()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_pixel_count.md)
  : Pixel Count Summary
- [`summary_quantile()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_quantile.md)
  : Quantile Summary
- [`summary_random_sample()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_random_sample.md)
  : Random Sample Summary
- [`summary_sd()`](https://lassa-sentinel.github.io/GeoTessera/reference/summary_sd.md)
  : Standard Deviation Summary

## Tile Operations

- [`Tile`](https://lassa-sentinel.github.io/GeoTessera/reference/Tile.md)
  : Tile Class for Embedding Data
- [`tile_from_geotiff()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_from_geotiff.md)
  : Create Tile from GeoTIFF file
- [`tile_from_npy()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_from_npy.md)
  : Create Tile from NPY files
- [`tile_from_world()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_from_world.md)
  : Convert world coordinates to tile coordinates
- [`tile_from_zarr()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_from_zarr.md)
  : Create Tile from Zarr archive
- [`tile_to_bounds()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_to_bounds.md)
  : Get tile bounds from center coordinates
- [`discover_tiles()`](https://lassa-sentinel.github.io/GeoTessera/reference/discover_tiles.md)
  : Discover tiles in a directory
- [`discover_formats()`](https://lassa-sentinel.github.io/GeoTessera/reference/discover_formats.md)
  : Discover tiles by format

## Coordinate Utilities

- [`tile_from_world()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_from_world.md)
  : Convert world coordinates to tile coordinates
- [`tile_to_bounds()`](https://lassa-sentinel.github.io/GeoTessera/reference/tile_to_bounds.md)
  : Get tile bounds from center coordinates

## Registry

- [`Registry`](https://lassa-sentinel.github.io/GeoTessera/reference/Registry.md)
  : Registry Class for Tessera Tile Metadata
- [`get_cache_dir()`](https://lassa-sentinel.github.io/GeoTessera/reference/get_cache_dir.md)
  : Get default cache directory

## Visualization

- [`visualization`](https://lassa-sentinel.github.io/GeoTessera/reference/visualization.md)
  : Visualization Functions
- [`visualize_global_coverage()`](https://lassa-sentinel.github.io/GeoTessera/reference/visualize_global_coverage.md)
  : Visualize global coverage
- [`create_rgb_mosaic()`](https://lassa-sentinel.github.io/GeoTessera/reference/create_rgb_mosaic.md)
  : Create RGB mosaic from GeoTIFFs
- [`create_pca_mosaic()`](https://lassa-sentinel.github.io/GeoTessera/reference/create_pca_mosaic.md)
  : Create PCA mosaic visualization
- [`plot_embedding_bands()`](https://lassa-sentinel.github.io/GeoTessera/reference/plot_embedding_bands.md)
  : Plot embedding bands
- [`analyze_geotiff_coverage()`](https://lassa-sentinel.github.io/GeoTessera/reference/analyze_geotiff_coverage.md)
  : Analyze GeoTIFF coverage
- [`calculate_bbox_from_file()`](https://lassa-sentinel.github.io/GeoTessera/reference/calculate_bbox_from_file.md)
  : Calculate bounding box from file
- [`create_coverage_summary()`](https://lassa-sentinel.github.io/GeoTessera/reference/create_coverage_summary.md)
  : Create coverage summary

## Country Lookup

- [`country`](https://lassa-sentinel.github.io/GeoTessera/reference/country.md)
  : Country Lookup Functions
- [`CountryLookup`](https://lassa-sentinel.github.io/GeoTessera/reference/CountryLookup.md)
  : Country Lookup Class
- [`get_country_bbox()`](https://lassa-sentinel.github.io/GeoTessera/reference/get_country_bbox.md)
  : Get bounding box for a country
- [`find_country_for_point()`](https://lassa-sentinel.github.io/GeoTessera/reference/find_country_for_point.md)
  : Find country for a point
