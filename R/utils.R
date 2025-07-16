cycle_id <- function(tsbl, period) {
  idx <- tsibble::index(tsbl)
  seq_along(tsbl[[idx]]) %% period + 1
}
