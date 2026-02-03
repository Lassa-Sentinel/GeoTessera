# Download file to temporary location

Download file to temporary location

## Usage

``` r
download_file_to_temp(
  url,
  expected_hash = NULL,
  cache_path = NULL,
  progress = TRUE
)
```

## Arguments

- url:

  URL to download from

- expected_hash:

  Optional expected SHA256 hash

- cache_path:

  Optional cache path to use instead of temp

- progress:

  Show progress bar

## Value

Path to downloaded file
