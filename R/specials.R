specials_gam <- new_specials(
  trend = function(){
    list(term = "trend")
  },
  season = function(period){
    list(period = period)
  },
  xreg = function(...){
    exprs <- enquos(...)
    list(xreg_terms = exprs)
  }
)
