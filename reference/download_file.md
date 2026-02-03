# Download a file with progress and optional hash verification

Download a file with progress and optional hash verification

## Usage

``` r
download_file(
  url,
  dest_path,
  expected_hash = NULL,
  progress = TRUE,
  max_retries = 3,
  timeout = 60
)
```

## Arguments

- url:

  URL to download from

- dest_path:

  Destination file path

- expected_hash:

  Optional expected SHA256 hash

- progress:

  Show progress bar

- max_retries:

  Maximum number of retry attempts

- timeout:

  Timeout in seconds

## Value

Path to downloaded file
