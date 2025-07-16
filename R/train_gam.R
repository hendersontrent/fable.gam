train_gam <- function(.data, specials, ...){

  resp <- tsibble::measured_vars(.data)[[1]]
  idx <- tsibble::index_var(.data)
  data <- tsibble::as_tibble(.data)
  data$time <- as.numeric(data[[idx]])

  # Build the GAM formula dynamically

  rhs_terms <- c()

  # Add trend() represented {mgcv} style as: s(time)

  if (!is.null(specials$trend)){
    rhs_terms <- c(rhs_terms, "s(time)")
  }

  # Add each season() represented {mgcv} style as: s(season_index, bs = 'cc', k = period, ...)

  for (season_spec in specials$season){
    period <- season_spec$period
    season_var <- paste0("season_", period)
    data[[season_var]] <- cycle_id(.data, period)
    rhs_terms <- c(rhs_terms, paste0("s(", season_var, ", bs = 'cc', k = ", period, ")")) # Cyclic cubic spline to ensure season start and end match up
  }

  # Add any xreg terms

  if (!is.null(specials$xreg)){
    for (x in specials$xreg$xreg_terms){
      rhs_terms <- c(rhs_terms, rlang::as_label(x))
    }
  }

  formula_str <- paste(resp, "~", paste(rhs_terms, collapse = " + "))
  formula_obj <- stats::as.formula(formula_str)

  fit <- mgcv::gam(formula_obj, data = data, ...)

  structure(
    list(model = fit),
    class = "fbl_gam"
  )
}

#--------------- Classes ----------------

gam_model <- new_model_class("GAM", train_gam, specials_gam)

#--------------- Core interface function ----------------

#' Generalised additive modelling
#'
#' Prepares a generalised additive model specification for use within the `fable` package.
#'
#' The GAM modelling interface uses a `formula` based model specification
#' `y ~ x`, where the left of the formula specifies the response variable,
#' and the right specifies the model's predictive terms, including any smooth
#' functions of exogenous regressors or 'covariates'.
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
#' @author Trent Henderson
#'
#'
#' @examples
#' if (requireNamespace("tsibble")) {
#' library(tsibble)
#' tsibble::tourism %>%
#'   filter(Region == "Melbourne") %>%
#'   model(mygam = GAM(Trips ~ trend() + season(4)))
#' }
#'
#' @export
#'
GAM <- function(formula, ...){
  fabletools::new_model_definition(gam_model, !!enquo(formula), ...)
}
