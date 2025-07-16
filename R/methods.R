#' Produce forecasts from the GAM
#'
#' If additional future information is required (such as exogenous variables or
#' carrying capacities) by the model, then they should be included as variables
#' of the `new_data` argument.
#'
#' @inheritParams fable::forecast.ARIMA
#' @param ... Additional arguments passed to [`stats::predict()`].
#'
#' @return A list of forecasts
#'
#' @author Trent Henderson
#'
#' @examples
#'
#' \donttest{
#' if (requireNamespace("tsibble")) {
#' library(tsibble)
#' tsibble::tourism %>%
#'   filter(Region == "Melbourne") %>%
#'   model(mygam = GAM(Trips ~ trend() + season(4))) %>%
#'   forecast(h = "5 years")
#' }
#' }
#'
#' @export
#'
forecast.fbl_gam <- function(object, new_data, specials = NULL, ...){
  model <- object$model
  idx_var <- tsibble::index_var(new_data)
  new_data$..time <- as.numeric(new_data[[idx_var]])

  # Add any seasonal variables back

  for (season_spec in specials$season) {
    period <- season_spec$period
    season_var <- paste0("..season_", period)
    new_data[[season_var]] <- cycle_id(new_data, period)
  }

  # Calculate predictions

  preds <- stats::predict(model, newdata = new_data, se.fit = TRUE, type = "response", ...)
  distributional::dist_normal(preds$fit, preds$se.fit)
}

#-------------- Fitted values and residuals --------------

#' Extract fitted values
#'
#' Extracts the fitted values from an estimated GAM
#'
#' @inheritParams fable::fitted.ARIMA
#'
#' @return A vector of fitted values
#'
#' @author Trent Henderson
#'
#' @export
#'
fitted.fbl_gam <- function(object, ...){
  fitted(object$model)
}

#' Extract model residuals
#'
#' Extracts the residuals from an estimated GAM
#'
#' @inheritParams fable::residuals.ARIMA
#'
#' @return A vector of residuals
#'
#' @author Trent Henderson
#'
#' @export
#'
residuals.fbl_gam <- function(object, ...){
  residuals(object$model)
}

#-------------- Other methods --------------

#' @export
model_sum.fbl_gam <- function(x){
  "gam"
}

#' @export
format.fbl_gam <- function(x, ...){
  "GAM"
}
