cycle_id <- function(data, idx, period) {
  seq_along(data[[idx]]) %% period + 1
}

get_season_var <- function(data, idx, period) {
  index_vals <- data[[idx]]
  if (inherits(index_vals, "yearmonth") && period == 12) {
    return(lubridate::month(index_vals))
  } else if (inherits(index_vals, "yearquarter") && period == 4) {
    return(lubridate::quarter(index_vals))
  } else if (inherits(index_vals, "yearweek") && period == 52) {
    return(lubridate::isoweek(index_vals))
  } else if (inherits(index_vals, "Date") && period == 7) {
    return(lubridate::wday(index_vals, week_start = 1))
  }
  cycle_id(data, idx, period)
}

# Adds `timevarnumeric`, `season_N`, and `xreg` columns to new_data, mirroring what `train_gam()` does for the training set.
# Used by both forecast() and generate().

prepare_gam_newdata <- function(new_data, specials) {
  idx_var <- tsibble::index_var(new_data)
  new_data$timevarnumeric <- as.numeric(new_data[[idx_var]])
  for (season_spec in specials$season) {
    period <- season_spec$period
    season_var <- paste0("season_", period)
    new_data[[season_var]] <- get_season_var(new_data, idx_var, period)
  }
  for (xreg_call in specials$xreg) {
    for (col_name in names(xreg_call$xreg_df)) {
      new_data[[make.names(col_name)]] <- xreg_call$xreg_df[[col_name]]
    }
  }
  new_data
}
