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
      smooth <- xreg_call$smooth
      k <- xreg_call$k
      bs <- xreg_call$bs
      xreg_df <- xreg_call$xreg_df
      for(col_name in names(xreg_df)){
        col_data <- xreg_df[[col_name]]
        safe_name <- make.names(col_name)
        data[[safe_name]] <- col_data
        if(smooth && is.numeric(col_data)){
          rhs_terms <- c(rhs_terms, paste0("s(", safe_name, ", k = ", k, ", bs = '", bs, "')"))
        } else {
          rhs_terms <- c(rhs_terms, safe_name)
        }
      }
    }
  }

  lhs <- rlang::sym(".gam_response")
  rhs <- rlang::parse_expr(paste(rhs_terms, collapse = " + "))
  formula_obj <- rlang::new_formula(lhs, rhs)

  # Model family

  if(!is.null(specials$family)){
    fam_obj <- specials$family[[1]]
    if(fam_obj$family == "Gamma" && fam_obj$link != "log"){
      abort("Gamma family requires a log link. Use family(Gamma, link = 'log') or family(Gamma(link = 'log')).")
    }
    if(fam_obj$family == "poisson" && fam_obj$link != "log"){
      abort("Poisson family requires a log link. Use family(poisson) or family(poisson, link = 'log').")
    }
    if(startsWith(fam_obj$family, "Negative Binomial") && fam_obj$link != "log"){
      abort("Negative Binomial family requires a log link. Use family(nb()) which defaults to log link.")
    }
  } else {
    fam_obj <- stats::gaussian()
  }

  # Use gamm() with AR correlation structure if errors() special is specified, otherwise use standard gam().
  # Non-Gaussian gamm() fits via penalised quasi-likelihood (PQL), which is an approximation —
  # AIC/BIC from the lme component are not true likelihoods in that case.

  if(!is.null(specials$errors)){
    ar_order <- specials$errors[[1]]$ar
    if(inherits(fam_obj, "extended.family")){
      abort(paste0(
        "The '", fam_obj$family, "' family is an mgcv extended family and cannot be used with errors(), ",
        "because gamm() does not support extended families. Fit without errors(), or use a standard ",
        "exponential family (e.g. gaussian, Gamma, poisson)."
      ))
    }
    if(fam_obj$family != "gaussian"){
      rlang::warn(paste0(
        fam_obj$family, " family with errors() uses gamm() via penalised quasi-likelihood (PQL). ",
        "Bootstrap intervals (bootstrap = TRUE) are recommended for prediction intervals."
      ))
    }
    fit_full <- mgcv::gamm(formula_obj, data = data, family = fam_obj,
                           correlation = nlme::corARMA(p = ar_order, q = 0), ...)
    fit <- fit_full$gam
    lme_fit <- fit_full$lme
  }else{
    fit <- mgcv::gam(formula_obj, data = data, family = fam_obj, ...)
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
#' Exogenous regressors can be included via the `xreg` special.
#'
#' \preformatted{
#' xreg(..., smooth = TRUE, k = -1, bs = "tp")
#' }
#'
#' \describe{
#'   \item{smooth}{If \code{TRUE}, numeric variables are automatically wrapped in \code{s()} for smooth non-linear estimation}
#'   \item{k}{Basis dimension passed to \code{s()}. Defaults to \code{-1} (mgcv auto-selects). Only used when \code{smooth = TRUE}}
#'   \item{bs}{Spline basis type passed to \code{s()}. Defaults to \code{"tp"} (thin plate). Only used when \code{smooth = TRUE}}
#' }
#' }
#'
#' \subsection{errors}{
#' The `errors` special adds an AR(p) correlation structure to the model residuals via `mgcv::gamm()`.
#' When specified, the model is fit using `gamm()` instead of `gam()`, which accounts for autocorrelation
#' remaining in the residuals after the smooth terms are included. This is analogous to dynamic regression
#' (regression with ARIMA errors) in `fable`. Only supported with the Gaussian family.
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
#' \subsection{family}{
#' The `family` special sets the GLM response family and link function, passed directly to
#' \code{mgcv::gam()}. Defaults to \code{gaussian(link = "identity")}.
#'
#' \preformatted{
#' family(family = gaussian, link = NULL)
#' }
#'
#' \describe{
#'   \item{family}{A family function (e.g. \code{Gamma}) or a pre-constructed family object
#'     (e.g. \code{Gamma(link = "log")}). Any family accepted by \code{mgcv::gam()} is valid.}
#'   \item{link}{Link function name as a character string (e.g. \code{"log"}). Only used when
#'     \code{family} is a function rather than a pre-built object.}
#' }
#'
#' The analytic forecast distribution is chosen based on the family and link:
#' \itemize{
#'   \item \code{gaussian} / \code{identity}: \code{dist_normal} (exact).
#'   \item \code{gaussian} or \code{Gamma} / \code{log}: \code{dist_lognormal} (the linear predictor
#'     is approximately normal on the log scale, so the response is approximately log-normal).
#'   \item \code{poisson} / \code{log}: \code{dist_poisson}.
#'   \item \code{nb} (Negative Binomial) / \code{log}: \code{dist_negative_binomial}.
#'   \item \code{betar} (Beta regression) / \code{logit}: \code{dist_beta}, with the response mean
#'     \code{mu} and precision \code{theta} mapped to shape parameters
#'     \code{shape1 = mu * theta} and \code{shape2 = (1 - mu) * theta}. The response must lie in
#'     the open interval \code{(0, 1)}. Note that \code{betar} is an mgcv extended family and
#'     cannot be combined with \code{errors()} (which fits via \code{gamm()}).
#'   \item All other combinations: \code{dist_normal} on the response scale via the delta method
#'     (approximation). Bootstrap intervals are recommended for these cases.
#' }
#' }
#'
#' @author Trent Henderson
#'
#'
#' @examples
#' \donttest{
#' library(dplyr)
#' library(tsibble)
#'
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
