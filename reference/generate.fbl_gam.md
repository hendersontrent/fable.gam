# Generate future sample paths from a GAM

Generates simulated future sample paths from a fitted \`GAM\`.
Innovations are resampled from the in-sample residuals, giving a
non-parametric empirical bootstrap.

## Usage

``` r
# S3 method for class 'fbl_gam'
generate(x, new_data, specials = NULL, ...)
```

## Arguments

- x:

  `fbl_gam` model object

- new_data:

  `tsibble` of future time points at which to generate paths

- specials:

  Parsed specials from the model formula

- ...:

  arguments to be passed to methods

## Author

Trent Henderson
