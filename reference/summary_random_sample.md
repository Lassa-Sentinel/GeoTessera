# Random Sample Summary

Factory function to create a random sampling summary function.

## Usage

``` r
summary_random_sample(n = 10, seed = NULL)
```

## Arguments

- n:

  Number of random points to sample

- seed:

  Random seed for reproducibility (NULL for no seed)

## Value

A summary function that returns embeddings at n random points

## Examples

``` r
if (FALSE) { # \dontrun{
summary_random_10 <- summary_random_sample(n = 10, seed = 42)

gt <- geotessera()
result <- gt$summarize_region(
  region = bbox,
  year = 2024,
  summary_fns = list(samples = summary_random_10)
)
} # }
```
