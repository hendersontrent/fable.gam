# Interpolate missing values using the GAM

Replaces \`NA\` values in the response variable with in-sample GAM
predictions evaluated at those time points.

## Usage

``` r
# S3 method for class 'fbl_gam'
interpolate(object, new_data, specials, ...)
```

## Arguments

- object:

  `fbl_gam` model object

- new_data:

  `tsibble` containing observations, some of which may be `NA`

- specials:

  Parsed specials from the model formula

- ...:

  arguments to be passed to methods

## Value

The `new_data` tsibble with missing values replaced by GAM predictions.

## Author

Trent Henderson
