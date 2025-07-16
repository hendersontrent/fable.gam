train_gam <- function(.data, specials, ...) {
  resp <- tsibble::measured_vars(.data)[[1]]
  idx <- tsibble::index_var(.data)
  data <- tsibble::as_tibble(.data)
  data$..time <- as.numeric(data[[idx]]) # For the trend

  # Build the GAM formula dynamically

  rhs_terms <- c()

  # Add trend() represented {mgcv} style as: s(..time)

  if (!is.null(specials$trend)) {
    rhs_terms <- c(rhs_terms, "s(..time)")
  }

  # Add each season() represented {mgcv} style as: s(seasonal_index, bs = 'cc', k = ...)

  for (season_spec in specials$season) {
    period <- season_spec$period
    season_var <- paste0("..season_", period)
    data[[season_var]] <- cycle_id(.data, period)
    rhs_terms <- c(rhs_terms, paste0("s(", season_var, ", bs = 'cc', k = ", period, ")")) # cc to ensure season start and end match up
  }

  # Add any xreg terms

  if (!is.null(specials$xreg)) {
    for (x in specials$xreg$xreg_terms) {
      rhs_terms <- c(rhs_terms, as_label(x))
    }
  }

  formula_str <- paste(resp, "~", paste(rhs_terms, collapse = " + "))
  formula_obj <- as.formula(formula_str)

  fit <- mgcv::gam(formula_obj, data = data, ...)

  structure(
    list(model = fit),
    class = "fbl_gam"
  )
}

#--------------- Classes ----------------

gam_model <- new_model_class("GAM", train_gam, specials_gam)

GAM <- function(formula, ...) {
  fabletools::new_model_definition(gam_model, !!enquo(formula), ...)
}

