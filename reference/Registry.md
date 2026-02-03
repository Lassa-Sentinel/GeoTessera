# Registry Class for Tessera Tile Metadata

Manages Parquet registry and HTTP downloads of Tessera data.

## Public fields

- `version`:

  Dataset version (e.g., "v1")

- `cache_dir`:

  Directory for caching registry files

- `embeddings_dir`:

  Directory for storing embeddings

- `registry_url`:

  Base URL for registry files

- `landmasks_registry_url`:

  Base URL for landmask registry files

- `verify_hashes`:

  Whether to verify file hashes

## Methods

### Public methods

- [`Registry$new()`](#method-Registry-new)

- [`Registry$load_tiles_for_region()`](#method-Registry-load_tiles_for_region)

- [`Registry$iter_tiles_in_region()`](#method-Registry-iter_tiles_in_region)

- [`Registry$get_available_years()`](#method-Registry-get_available_years)

- [`Registry$get_tile_counts_by_year()`](#method-Registry-get_tile_counts_by_year)

- [`Registry$embeddings_count()`](#method-Registry-embeddings_count)

- [`Registry$fetch()`](#method-Registry-fetch)

- [`Registry$fetch_landmask()`](#method-Registry-fetch_landmask)

- [`Registry$get_tile_file_size()`](#method-Registry-get_tile_file_size)

- [`Registry$get_scales_file_size()`](#method-Registry-get_scales_file_size)

- [`Registry$calculate_download_requirements()`](#method-Registry-calculate_download_requirements)

- [`Registry$get_manifest_info()`](#method-Registry-get_manifest_info)

- [`Registry$get_landmask_count()`](#method-Registry-get_landmask_count)

- [`Registry$clone()`](#method-Registry-clone)

------------------------------------------------------------------------

### Method [`new()`](https://rdrr.io/r/methods/new.html)

Create a new Registry object

#### Usage

    Registry$new(
      version = "v1",
      cache_dir = NULL,
      embeddings_dir = NULL,
      registry_url = NULL,
      registry_path = NULL,
      registry_dir = NULL,
      landmasks_registry_url = NULL,
      landmasks_registry_path = NULL,
      verify_hashes = TRUE
    )

#### Arguments

- `version`:

  Dataset version (default "v1")

- `cache_dir`:

  Directory for caching (default: user cache dir)

- `embeddings_dir`:

  Directory for embeddings (default: current dir)

- `registry_url`:

  Base URL for registry (default: Tessera server)

- `registry_path`:

  Local path to registry file (overrides URL)

- `registry_dir`:

  Local directory containing registry files

- `landmasks_registry_url`:

  URL for landmask registry

- `landmasks_registry_path`:

  Local path to landmask registry

- `verify_hashes`:

  Verify SHA256 hashes on downloads

#### Returns

A new Registry object

------------------------------------------------------------------------

### Method `load_tiles_for_region()`

Get tiles in a geographic region

#### Usage

    Registry$load_tiles_for_region(bbox, year, progress = TRUE)

#### Arguments

- `bbox`:

  Bounding box (sf bbox, named vector, or list with xmin, ymin, xmax,
  ymax)

- `year`:

  Integer year

- `progress`:

  Show progress

#### Returns

Data frame of tile metadata

------------------------------------------------------------------------

### Method `iter_tiles_in_region()`

Iterate over tiles in a region (lazy evaluation)

#### Usage

    Registry$iter_tiles_in_region(bbox, year)

#### Arguments

- `bbox`:

  Bounding box

- `year`:

  Integer year

#### Returns

Iterator/generator function

------------------------------------------------------------------------

### Method `get_available_years()`

Get available years in the registry

#### Usage

    Registry$get_available_years()

#### Returns

Integer vector of years

------------------------------------------------------------------------

### Method `get_tile_counts_by_year()`

Get tile counts by year

#### Usage

    Registry$get_tile_counts_by_year()

#### Returns

Named integer vector

------------------------------------------------------------------------

### Method `embeddings_count()`

Count embeddings in a bounding box

#### Usage

    Registry$embeddings_count(bbox, year)

#### Arguments

- `bbox`:

  Bounding box

- `year`:

  Integer year

#### Returns

Integer count

------------------------------------------------------------------------

### Method `fetch()`

Fetch an embedding file

#### Usage

    Registry$fetch(
      year,
      lon,
      lat,
      is_scales = FALSE,
      expected_hash = NULL,
      progress = TRUE
    )

#### Arguments

- `year`:

  Integer year

- `lon`:

  Tile longitude

- `lat`:

  Tile latitude

- `is_scales`:

  Fetch scales file instead of embedding

- `expected_hash`:

  Expected SHA256 hash

- `progress`:

  Show progress

#### Returns

Path to downloaded file

------------------------------------------------------------------------

### Method `fetch_landmask()`

Fetch a landmask file

#### Usage

    Registry$fetch_landmask(lon, lat, expected_hash = NULL, progress = TRUE)

#### Arguments

- `lon`:

  Tile longitude

- `lat`:

  Tile latitude

- `expected_hash`:

  Expected SHA256 hash

- `progress`:

  Show progress

#### Returns

Path to downloaded file

------------------------------------------------------------------------

### Method `get_tile_file_size()`

Get file size for an embedding tile

#### Usage

    Registry$get_tile_file_size(year, lon, lat)

#### Arguments

- `year`:

  Integer year

- `lon`:

  Tile longitude

- `lat`:

  Tile latitude

#### Returns

Integer file size in bytes

------------------------------------------------------------------------

### Method `get_scales_file_size()`

Get file size for scales file

#### Usage

    Registry$get_scales_file_size(year, lon, lat)

#### Arguments

- `year`:

  Integer year

- `lon`:

  Tile longitude

- `lat`:

  Tile latitude

#### Returns

Integer file size in bytes

------------------------------------------------------------------------

### Method `calculate_download_requirements()`

Calculate download requirements for tiles

#### Usage

    Registry$calculate_download_requirements(tiles, output_dir, format = "tiff")

#### Arguments

- `tiles`:

  Data frame of tiles

- `output_dir`:

  Output directory

- `format`:

  Output format ("tiff", "zarr", "npy")

#### Returns

Named list with total_size, tiles_to_download, tiles_existing

------------------------------------------------------------------------

### Method `get_manifest_info()`

Get manifest info (git hash and repo URL)

#### Usage

    Registry$get_manifest_info()

#### Returns

Named list with git_hash and repo_url

------------------------------------------------------------------------

### Method `get_landmask_count()`

Get count of available landmasks

#### Usage

    Registry$get_landmask_count()

#### Returns

Integer count

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Registry$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
