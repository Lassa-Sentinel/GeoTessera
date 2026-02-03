# Dequantize embedding data

Convert int8 quantized embeddings back to float32 using scale factors.
Supports both per-channel scales (128 values) and per-pixel scales (H x
W matrix).

## Usage

``` r
dequantize_embedding(quantized_embedding, scales)
```

## Arguments

- quantized_embedding:

  Integer matrix/array of quantized values (H x W x C)

- scales:

  Numeric array of scale factors - either vector (128) or matrix (H x W)

## Value

Numeric array of dequantized embeddings
