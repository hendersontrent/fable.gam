# Generalised additive modelling

Prepares a generalised additive model specification for use within the
\`fable\` package.

## Usage

``` r
GAM(formula, ...)
```

## Arguments

- formula:

  A symbolic description of the model to be fitted of class \`formula\`

- ...:

  further arguments for passing on e.g. to `gam.fit3` (such as
  `mustart`).

## Specials

### trend

The \`trend\` special is used to specify a trend component


    trend()

### trend2

The \`trend2\` special is used to specify a nonlinear trend component
that is modelled via smooth functions


    trend2()

### season

The \`season\` special is used to specify a seasonal component. This
special can be used multiple times for different seasonalities.

\*\*NOTE: The inputs controlling the seasonal \`period\` refer to the
number of time points in each seasonal period.\*\*


    season(period = NULL)

### xreg

Exogenous regressors can be included via the \`xreg\` special.


    xreg(..., smooth = TRUE, k = -1, bs = "tp")

- smooth:

  If `TRUE`, numeric variables are automatically wrapped in `s()` for
  smooth function estimation

- k:

  Basis dimension passed to `s()`. Defaults to `-1` (whereby mgcv
  automatically chooses k). Only used when `smooth = TRUE`

- bs:

  Spline basis type passed to `s()`. Defaults to `"tp"` (thin plate).
  Only used when `smooth = TRUE`

### errors

The \`errors\` special adds an autoregressive correlation structure to
the model residuals. When specified, the model is fit using \`gamm()\`
instead of \`gam()\`.


    errors(ar = 1)

- ar:

  Order of the autoregressive error process. Must be a positive integer.
  Defaults to 1

### family

The \`family\` special sets the response family and link function,
passed directly to
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). Defaults to
`gaussian(link = "identity")`


    family(family = gaussian, link = NULL)

- family:

  Family function (e.g. `Gamma`) or family function with link function
  (e.g. `Gamma(link = "log")`)

- link:

  Link function name as a character string (e.g. `"log"`)

## Author

Trent Henderson

## Examples

``` r
# \donttest{
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union
library(tsibble)
#> 
#> Attaching package: ‘tsibble’
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, union

tourism_melb <- tsibble::tourism |>
  filter(Region == "Melbourne") |>
  filter(Purpose == "Business") |>
  dplyr::select(c(Quarter, Region, Trips)) |>
  as_tsibble(key = Region, index = Quarter)

fit <- tourism_melb |>
  model(mygam = GAM(Trips ~ trend() + season(4))) |>
  forecast(h = "5 years")
# }
```
