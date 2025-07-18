specials_gam <- new_specials(
  trend = function(){
    list(term = "trend")
  },
  trend2 = function(k = -1, bs = "tp"){
    list(k = k,
         bs = bs)
  },
  season = function(period){
    list(period = period)
  },
  xreg = function(...){
    exprs <- enquos(...)
    list(xreg_terms = exprs)
  }
)
