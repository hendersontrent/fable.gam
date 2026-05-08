train_gam <- function(.data, specials, ...){

  if(length(tsibble::measured_vars(.data)) > 1){
    abort("Only univariate responses are currently supported by GAM.")
  }

  if(nrow(.data) < 5){
    abort("Insufficient data to fit a GAM.") # Probably need a better threshold...
  }

  resp <- tsibble::measured_vars(.data)[[1]]
  idx <- tsibble::index_var(.data)
  data <- tsibble::as_tibble(.data)
  data$.gam_response <- data[[resp]] # Copy the response into a safe column name in the case of transformations in `fable` like `log()`
  data$timevarnumeric <- as.numeric(data[[idx]])

  if(all(is.na(data$.gam_response))){
    abort("All observations are missing, a model cannot be estimated without data.")
  }

  # Build the GAM formula dynamically

  rhs_terms <- c()

  # If applicable, add user's custom specified trend smooth

  if(!is.null(specials$trend2)){
    rhs_terms <- c(rhs_terms, as.character(paste0("s(timevarnumeric, ", "k = ", specials$trend2[[1]]$k,
                                                  ", bs = '", specials$trend2[[1]]$bs, "')")))
  } else{
    if(!is.null(specials$trend)){
      rhs_terms <- c(rhs_terms, "s(timevarnumeric)") # Add trend() represented {mgcv} style as: s(time)
    }
  }

  # Add each season() represented {mgcv} style as: s(season_index, bs = 'cc', k = period, ...)

  for(season_spec in specials$season){
    period <- season_spec$period
    season_var <- paste0("season_", period)
    data[[season_var]] <- get_season_var(data, idx, period)
    rhs_terms <- c(rhs_terms, paste0("s(", season_var, ", bs = 'cc', k = ", period, ")")) # Cyclic cubic spline to ensure season start and end match up
  }

  # Add any xreg terms

  if(!is.null(specials$xreg)){
    for(xreg_call in specials$xreg){
      for(x in xreg_call$xreg_terms){
        rhs_terms <- c(rhs_terms, rlang::as_label(x))
      }
    }
  }

  lhs <- rlang::sym(".gam_response")
  rhs <- rlang::parse_expr(paste(rhs_terms, collapse = " + "))
  formula_obj <- rlang::new_formula(lhs, rhs)

  # Use gamm() with AR correlation structure if errors() special is specified, otherwise use standard gam()

  if(!is.null(specials$errors)){
    ar_order <- specials$errors[[1]]$ar
    fit_full <- mgcv::gamm(formula_obj, data = data,
                           correlation = nlme::corARMA(p = ar_order, q = 0), ...)
    fit <- fit_full$gam
    lme_fit <- fit_full$lme
  }else{
    fit <- mgcv::gam(formula_obj, data = data, ...)
    lme_fit <- NULL
  }

  structure(
    list(model = fit,
         lme = lme_fit,
         response = resp),
    class = "fbl_gam"
  )
}

#--------------- Core interface function ----------------

#' Generalised additive modelling
#'
#' Prepares a generalised additive model specification for use within the `fable` package.
#'
#' The GAM modelling interface uses a `formula` based model specification `y ~ x`, where the left of the formula specifies the response variable, and the right specifies the model's predictive terms, including any smooth functions of exogenous regressors
#'
#'
#' @param formula A symbolic description of the model to be fitted of class `formula`.
#' @inheritParams mgcv::gam
#'
#' @section Specials:
#'
#' \subsection{trend}{
#' The `trend` special is used to specify a seasonal component. This special can be used multiple times for different seasonalities.
#'
#' \preformatted{
#' trend()
#' }
#' }
#'
#' \subsection{season}{
#' The `season` special is used to specify a seasonal component. This special can be used multiple times for different seasonalities.
#'
#' **NOTE: The inputs controlling the seasonal `period` refer to the number of observations in each seasonal period, not the number of days.**
#'
#' \preformatted{
#' season(period = NULL)
#' }
#' }
#'
#' \subsection{xreg}{
#' Exogenous regressors can be passed into `GAM` just like a regular `mgcv::gam` call by specifying the variable name or any smooth terms you want to model.
#' }
#'
#' \subsection{errors}{
#' The `errors` special adds an AR(p) correlation structure to the model residuals via `mgcv::gamm()`.
#' When specified, the model is fit using `gamm()` instead of `gam()`, which accounts for autocorrelation
#' remaining in the residuals after the smooth terms are included. This is analogous to dynamic regression
#' (regression with ARIMA errors) in `fable`.
#'
#' \preformatted{
#' errors(ar = 1)
#' }
#'
#' \describe{
#'   \item{ar}{Order of the autoregressive error process. Must be a positive integer. Default: 1.}
#' }
#' }
#'
#' @author Trent Henderson
#'
#'
#' @examples
#' \donttest{
#' tourism_melb <- tsibble::tourism |>
#'   filter(Region == "Melbourne") |>
#'   filter(Purpose == "Business") |>
#'   dplyr::select(c(Quarter, Region, Trips)) |>
#'   as_tsibble(key = Region, index = Quarter)
#'
#' fit <- tourism_melb |>
#'   model(mygam = GAM(Trips ~ trend() + season(4))) |>
#'   forecast(h = "5 years")
#' }
#'
#' @export
#'
GAM <- function(formula, ...){
  gam_model <- fabletools::new_model_class("GAM", train = train_gam, specials = specials_gam)
  fabletools::new_model_definition(gam_model, !!enquo(formula), ...)
}
