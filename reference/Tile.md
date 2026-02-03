# Tile Class for Embedding Data

Format-agnostic tile abstraction supporting NPY, GeoTIFF, and Zarr
storage.

## Public fields

- `lon`:

  Tile center longitude

- `lat`:

  Tile center latitude

- `year`:

  Data year

- `format`:

  Storage format ("npy", "geotiff", or "zarr")

- `path`:

  Path to the data file

- `scales_path`:

  Path to scales file (for NPY format)

- `landmask_path`:

  Path to landmask file

## Methods

### Public methods

- [`Tile$new()`](#method-Tile-new)

- [`Tile$get_grid_name()`](#method-Tile-get_grid_name)

- [`Tile$get_bounds()`](#method-Tile-get_bounds)

- [`Tile$get_bbox()`](#method-Tile-get_bbox)

- [`Tile$get_crs()`](#method-Tile-get_crs)

- [`Tile$get_transform()`](#method-Tile-get_transform)

- [`Tile$get_dimensions()`](#method-Tile-get_dimensions)

- [`Tile$is_available()`](#method-Tile-is_available)

- [`Tile$load_embedding()`](#method-Tile-load_embedding)

- [`Tile$contains_point()`](#method-Tile-contains_point)

- [`Tile$sample_at_point()`](#method-Tile-sample_at_point)

- [`Tile$to_list()`](#method-Tile-to_list)

- [`Tile$print()`](#method-Tile-print)

- [`Tile$clone()`](#method-Tile-clone)

------------------------------------------------------------------------

### Method [`new()`](https://rdrr.io/r/methods/new.html)

Create a new Tile object

#### Usage

    Tile$new(
      lon,
      lat,
      year,
      format = "npy",
      path = NULL,
      scales_path = NULL,
      landmask_path = NULL
    )

#### Arguments

- `lon`:

  Tile center longitude

- `lat`:

  Tile center latitude

- `year`:

  Data year

- `format`:

  Storage format

- `path`:

  Path to data file

- `scales_path`:

  Path to scales file (for NPY)

- `landmask_path`:

  Path to landmask file

#### Returns

A new Tile object

------------------------------------------------------------------------

### Method `get_grid_name()`

Get the grid name for this tile

#### Usage

    Tile$get_grid_name()

#### Returns

Character string grid name

------------------------------------------------------------------------

### Method `get_bounds()`

Get the bounding box for this tile

#### Usage

    Tile$get_bounds()

#### Returns

Named list with xmin, ymin, xmax, ymax

------------------------------------------------------------------------

### Method `get_bbox()`

Get the bounding box as an sf bbox object

#### Usage

    Tile$get_bbox()

#### Returns

sf bbox object

------------------------------------------------------------------------

### Method `get_crs()`

Get the CRS (Coordinate Reference System)

#### Usage

    Tile$get_crs()

#### Returns

sf crs object (WGS84 for geographic, UTM for GeoTIFF)

------------------------------------------------------------------------

### Method `get_transform()`

Get the affine transform

#### Usage

    Tile$get_transform()

#### Returns

Named list with resolution and origin info

------------------------------------------------------------------------

### Method `get_dimensions()`

Get tile dimensions

#### Usage

    Tile$get_dimensions()

#### Returns

Named list with height, width, channels

------------------------------------------------------------------------

### Method `is_available()`

Check if data files are available

#### Usage

    Tile$is_available(require_landmask = FALSE)

#### Arguments

- `require_landmask`:

  Also require landmask to be available

#### Returns

Logical

------------------------------------------------------------------------

### Method `load_embedding()`

Load the embedding data

#### Usage

    Tile$load_embedding()

#### Returns

3D array with dimensions (height, width, channels)

------------------------------------------------------------------------

### Method `contains_point()`

Check if a point is within this tile

#### Usage

    Tile$contains_point(lon, lat)

#### Arguments

- `lon`:

  Longitude

- `lat`:

  Latitude

#### Returns

Logical

------------------------------------------------------------------------

### Method `sample_at_point()`

Sample embedding at a specific point

#### Usage

    Tile$sample_at_point(lon, lat)

#### Arguments

- `lon`:

  Longitude

- `lat`:

  Latitude

#### Returns

Numeric vector of embedding values (128 channels)

------------------------------------------------------------------------

### Method `to_list()`

Convert tile info to a list

#### Usage

    Tile$to_list()

#### Returns

Named list

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print tile summary

#### Usage

    Tile$print()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Tile$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
