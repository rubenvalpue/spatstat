#
#   ppx.R
#
#  class of general point patterns in any dimension
#
#  $Revision: 1.62 $  $Date: 2019/01/02 07:56:32 $
#

ppx <- local({
  
  ctype.table <- c("spatial", "temporal", "local", "mark")
  ctype.real  <- c(TRUE,      TRUE,       FALSE,   FALSE)

  ppx <- function(data, domain=NULL, coord.type=NULL, simplify=FALSE) {
    data <- as.hyperframe(data)
    # columns suitable for spatial coordinates
    suitable <- with(unclass(data),
                     vtype == "dfcolumn" &
                     (vclass == "numeric" | vclass == "integer"))
    if(is.null(coord.type)) {
      # assume all suitable columns of data are spatial coordinates
      # and all other columns are marks.
      ctype <- ifelse(suitable, "spatial", "mark")
    } else {
      stopifnot(is.character(coord.type))
      stopifnot(length(coord.type) == ncol(data))
      ctypeid <- pmatch(coord.type, ctype.table, duplicates.ok=TRUE)
      # validate
      if(any(uhoh <- is.na(ctypeid)))
        stop(paste("Unrecognised coordinate",
                   ngettext(sum(uhoh), "type", "types"),
                   commasep(sQuote(coord.type[uhoh]))))
      if(any(uhoh <- (!suitable & ctype.real[ctypeid]))) {
        nuh <- sum(uhoh)
        stop(paste(ngettext(nuh, "Coordinate", "Coordinates"),
                   commasep(sQuote(names(data)[uhoh])),
                   ngettext(nuh, "does not", "do not"),
                   "contain real numbers"))
      }
      ctype <- ctype.table[ctypeid]
    }
    ctype <- factor(ctype, levels=ctype.table)
    #
    if(simplify && all(ctype == "spatial")) {
       # attempt to reduce to ppp or pp3
      d <- length(ctype)
      if(d == 2) {
        ow <- try(as.owin(domain), silent=TRUE)
        if(!inherits(ow, "try-error")) {
          X <- try(as.ppp(as.data.frame(data), W=ow))
          if(!inherits(X, "try-error"))
            return(X)
        }
      } else if(d == 3) {
        bx <- try(as.box3(domain), silent=TRUE)
        if(!inherits(bx, "try-error")) {
          m <- as.matrix(as.data.frame(data))
          X <- try(pp3(m[,1], m[,2], m[,3], bx))
          if(!inherits(X, "try-error"))
            return(X)
        }
      }
    }
    out <- list(data=data, ctype=ctype, domain=domain)
    class(out) <- "ppx"
    return(out)
  }

  ppx
})


is.ppx <- function(x) { inherits(x, "ppx") }

nobjects.ppx <- npoints.ppx <- function(x) { nrow(x$data) }

print.ppx <- function(x, ...) {
  cat("Multidimensional point pattern\n")
  sd <- summary(x$data)
  np <- sd$ncases
  nama <- sd$col.names
  cat(paste(np, ngettext(np, "point", "points"), "\n"))
  if(any(iscoord <- (x$ctype == "spatial")))
    cat(paste(sum(iscoord), "-dimensional space coordinates ",
              paren(paste(nama[iscoord], collapse=",")), "\n", sep=""))
  if(any(istime <- (x$ctype == "temporal")))
    cat(paste(sum(istime), "-dimensional time coordinates ",
              paren(paste(nama[istime], collapse=",")), "\n", sep=""))
  if(any(islocal <- (x$ctype == "local"))) 
    cat(paste(sum(islocal), ngettext(sum(islocal), "column", "columns"),
              "of local coordinates:",
              commasep(sQuote(nama[islocal])), "\n"))
  if(any(ismark <- (x$ctype == "mark"))) 
    cat(paste(sum(ismark), ngettext(sum(ismark), "column", "columns"),
              "of marks:",
              commasep(sQuote(nama[ismark])), "\n"))
  if(!is.null(x$domain)) {
    cat("Domain:\n\t")
    print(x$domain)
  }
  invisible(NULL)
}

summary.ppx <- function(object, ...) { object }

plot.ppx <- function(x, ...) {
  xname <- short.deparse(substitute(x))
  coo <- coords(x, local=FALSE)
  dom <- x$domain
  m <- ncol(coo)
  if(m == 1) {
    coo <- coo[,1]
    ran <- diff(range(coo))
    ylim <- c(-1,1) * ran/20
    do.call(plot.default,
            resolve.defaults(list(coo, numeric(length(coo))),
                             list(...),
                             list(asp=1, ylim=ylim,
                                  axes=FALSE, xlab="", ylab="")))
    axis(1, pos=ylim[1])
  } else if(m == 2) {
    if(is.null(dom)) {
      # plot x, y coordinates only
      nama <- names(coo)
      do.call.matched(plot.default,
                      resolve.defaults(list(x=coo[,1], y=coo[,2], asp=1),
                                       list(...),
                                       list(main=xname),
                                       list(xlab=nama[1], ylab=nama[2])))
    } else {
      add <- resolve.defaults(list(...), list(add=FALSE))$add
      if(!add) {
        # plot domain, whatever it is
        do.call(plot, resolve.defaults(list(dom),
                                       list(...),
                                       list(main=xname)))
      }
      # convert to ppp
      x2 <- ppp(coo[,1], coo[,2], window=as.owin(dom),
                marks=as.data.frame(marks(x)), check=FALSE)
      # invoke plot.ppp
      return(do.call(plot, resolve.defaults(list(x2),
                                              list(add=TRUE),
                                              list(...))))
    }
  } else if(m == 3) {
    # convert to pp3
    if(is.null(dom))
      dom <- box3(range(coo[,1]), range(coo[,2]), range(coo[,3]))
    x3 <- pp3(coo[,1], coo[,2], coo[,3], dom)
    # invoke plot.pp3
    nama <- names(coo)
    do.call(plot,
            resolve.defaults(list(x3),
                             list(...),
                             list(main=xname),
                             list(xlab=nama[1], ylab=nama[2], zlab=nama[3])))
  } else stop(paste("Don't know how to plot a general point pattern in",
               ncol(coo), "dimensions"))
  return(invisible(NULL))
}

"[.ppx" <- function (x, i, drop=FALSE, ...) {
  da <- x$data
  dom <- x$domain
  if(!missing(i)) {
    if(inherits(i, c("boxx", "box3"))) {
      dom <- i
      i <- inside.boxx(da, w=i)
    }
    da <- da[i, , drop=FALSE]
  }
  out <- list(data=da, ctype=x$ctype, domain=dom)
  class(out) <- "ppx"
  if(drop) {
    # remove unused factor levels
    mo <- marks(out)
    switch(markformat(mo),
           none = { },
           vector = {
             if(is.factor(mo))
               marks(out) <- factor(mo)
           },
           dataframe = {
             isfac <- sapply(mo, is.factor)
             if(any(isfac))
               mo[, isfac] <- lapply(mo[, isfac], factor)
             marks(out) <- mo
           },
           hyperframe = {
             lmo <- as.list(mo)
             isfac <- sapply(lmo, is.factor)
             if(any(isfac))
               mo[, isfac] <- as.hyperframe(lapply(lmo[isfac], factor))
             marks(out) <- mo
           })
  }
  return(out)
}

domain <- function(X, ...) { UseMethod("domain") }

domain.ppx <- function(X, ...) { X$domain }

coords <- function(x, ...) {
  UseMethod("coords")
}

coords.ppx <- function(x, ..., spatial=TRUE, temporal=TRUE, local=TRUE) {
  ctype <- x$ctype
  chosen <- (ctype == "spatial" & spatial) |
            (ctype == "temporal" & temporal) | 
            (ctype == "local" & local) 
  as.data.frame(x$data[, chosen, drop=FALSE])
}

coords.ppp <- function(x, ...) { data.frame(x=x$x,y=x$y) }

"coords<-" <- function(x, ..., value) {
  UseMethod("coords<-")
}

"coords<-.ppp" <- function(x, ..., value) {
  win <- x$window
  if(is.null(value)) {
    # empty pattern
    return(ppp(window=win))
  }
  value <- as.data.frame(value)
  if(ncol(value) != 2)
    stop("Expecting a 2-column matrix or data frame, or two vectors")
  result <- as.ppp(value, win)
  marks(result) <- marks(x)
  return(result)
}

"coords<-.ppx" <- function(x, ..., spatial=TRUE, temporal=TRUE, local=TRUE, value) {
  ctype <- x$ctype
  chosen <- (ctype == "spatial" & spatial) |
            (ctype == "temporal" & temporal) | 
            (ctype == "local" & local) 
  x$data[, chosen] <- value
  return(x)
}

as.hyperframe.ppx <- function(x, ...) { x$data }

as.data.frame.ppx <- function(x, ...) { as.data.frame(x$data, ...) } 

as.matrix.ppx <- function(x, ...) { as.matrix(as.data.frame(x, ...)) }

marks.ppx <- function(x, ..., drop=TRUE) {
  ctype <- x$ctype
  chosen <- (ctype == "mark")
  if(!any(chosen)) return(NULL)
  x$data[, chosen, drop=drop]
}

"marks<-.ppx" <- function(x, ..., value) {
  ctype <- x$ctype
  retain <- (ctype != "mark")
  coorddata <- x$data[, retain, drop=FALSE]
  if(is.null(value)) {
    newdata <- coorddata
    newctype <- ctype[retain]
  } else {
    if(is.matrix(value) && nrow(value) == nrow(x$data)) {
      # assume matrix is to be treated as data frame
      value <- as.data.frame(value)
    }
    if(!is.data.frame(value) && !is.hyperframe(value)) 
      value <- hyperframe(marks=value)
    if(is.hyperframe(value) || is.hyperframe(coorddata)) {
      value <- as.hyperframe(value)
      coorddata <- as.hyperframe(coorddata)
    }
    if(ncol(value) == 0) {
      newdata <- coorddata
      newctype <- ctype[retain]
    } else {
      if(nrow(coorddata) == 0) 
        value <- value[integer(0), , drop=FALSE]
      newdata <- cbind(coorddata, value)
      newctype <- factor(c(as.character(ctype[retain]),
                           rep.int("mark", ncol(value))),
                         levels=levels(ctype))
    }
  }
  out <- list(data=newdata, ctype=newctype, domain=x$domain)
  class(out) <- class(x)
  return(out)
}

unmark.ppx <- function(X) {
  marks(X) <- NULL
  return(X)
}

markformat.ppx <- function(x) {
  mf <- x$markformat
  if(is.null(mf)) 
    mf <- markformat(marks(x))
  return(mf)
}

boxx <- function(..., unitname=NULL) {
  if(length(list(...)) == 0)
    stop("No data")
  ranges <- data.frame(...)
  nama <- names(list(...))
  if(is.null(nama) || !all(nzchar(nama)))
    names(ranges) <- paste("x", 1:ncol(ranges),sep="")
  if(nrow(ranges) != 2)
    stop("Data should be vectors of length 2")
  if(any(unlist(lapply(ranges, diff)) <= 0))
    stop("Illegal range: Second element <= first element")
  out <- list(ranges=ranges, units=as.unitname(unitname))
  class(out) <- "boxx"
  return(out)
}

as.boxx <- function(..., warn.owin = TRUE) {
  a <- list(...)
  n <- length(a)
  if (n == 0) 
    stop("No arguments given")
  if (n == 1) {
    a <- a[[1]]
    if (inherits(a, "boxx")) 
      return(a)
    if (inherits(a, "box3")) 
      return(boxx(a$xrange, a$yrange, a$zrange, 
		  unitname = as.unitname(a$units)))
    if (inherits(a, "owin")) {
      if (!is.rectangle(a) && warn.owin) 
        warning("The owin object does not appear to be rectangular - the bounding box is used!")
      return(boxx(a$xrange, a$yrange, unitname = as.unitname(a$units)))
    }
    if (is.numeric(a)) {
      if ((length(a)%%2) == 0) 
        return(boxx(split(a, rep(1:(length(a)/2), each = 2))))
      stop(paste("Don't know how to interpret", length(a), "numbers as a box"))
    }
    if (!is.list(a)) 
      stop("Don't know how to interpret data as a box")
  }
  return(do.call(boxx, a))
}

print.boxx <- function(x, ...) {
  m <- ncol(x$ranges)
  cat(paste(m, "-dimensional box:\n", sep=""))
  bracket <- function(z) paste("[",
                               paste(signif(z, 5), collapse=", "),
                               "]", sep="")
  v <- paste(unlist(lapply(x$ranges, bracket)), collapse=" x ")
  s <- summary(unitname(x))
  cat(paste(v, s$plural, s$explain, "\n"))
  invisible(NULL)
}

unitname.boxx <- function(x) { as.unitname(x$units) }

"unitname<-.boxx" <- function(x, value) {
  x$units <- as.unitname(value)
  return(x)
}

unitname.ppx <- function(x) { unitname(x$domain) }

"unitname<-.ppx" <- function(x, value) {
  d <- x$domain
  unitname(d) <- value
  x$domain <- d
  return(x)
}

as.owin.boxx <- function(W, ..., fatal=TRUE) {
  ra <- W$ranges
  if(length(ra) == 2) return(owin(ra[[1]], ra[[2]]))
  if(fatal) stop(paste("Cannot interpret box of dimension",
                       length(ra), "as a window"))
  return(NULL)
}

sidelengths.boxx <- function(x) {
  stopifnot(inherits(x, "boxx"))
  y <- unlist(lapply(x$ranges, diff))
  return(y)
}
  
volume.boxx <- function(x) {
  prod(sidelengths(x))
}

diameter.boxx <- function(x) {
  d <- sqrt(sum(sidelengths(x)^2))
  return(d)
}

shortside.boxx <- function(x) {
  return(min(sidelengths(x)))
}

eroded.volumes.boxx <- local({

  eroded.volumes.boxx <- function(x, r) {
    len <- sidelengths(x)
    ero <- sapply(as.list(len), erode1side, r=r)
    apply(ero, 1, prod)
  }

  erode1side <- function(z, r) { pmax.int(0, z - 2 * r)}
  
  eroded.volumes.boxx
})


runifpointx <- function(n, domain, nsim=1, drop=TRUE) {
  check.1.integer(n)
  check.1.integer(nsim)
  stopifnot(inherits(domain, "boxx"))
  ra <- domain$ranges
  d <- length(ra)
  result <- vector(mode="list", length=nsim)
  for(i in 1:nsim) {
    if(n == 0) {
      coo <- matrix(numeric(0), nrow=0, ncol=d)
    } else {
      coo <- mapply(runif,
                    n=rep(n, d),
                    min=ra[1,],
                    max=ra[2,])
      if(!is.matrix(coo)) coo <- matrix(coo, ncol=d)
    }
    colnames(coo) <- colnames(ra)
    df <- as.data.frame(coo)
    result[[i]] <- ppx(df, domain, coord.type=rep("s", d))
  }
  if(nsim == 1 && drop)
    return(result[[1]])
  result <- as.anylist(result)
  names(result) <- paste("Simulation", 1:nsim)
  return(result)
}

rpoisppx <- function(lambda, domain, nsim=1, drop=TRUE) {
  stopifnot(inherits(domain, "boxx"))
  stopifnot(is.numeric(lambda) && length(lambda) == 1 && lambda >= 0)
  n <- rpois(nsim, lambda * volume.boxx(domain))
  result <- vector(mode="list", length=nsim)
  for(i in 1:nsim) 
    result[[i]] <- runifpointx(n[i], domain)
  if(nsim == 1 && drop)
    return(result[[1]])
  result <- as.anylist(result)
  names(result) <- paste("Simulation", 1:nsim)
  return(result)
}

unique.ppx <- function(x, ..., warn=FALSE) {
  dup <- duplicated(x, ...)
  if(!any(dup)) return(x)
  if(warn) warning(paste(sum(dup), "duplicated points were removed"),
                   call.=FALSE)
  y <- x[!dup]
  return(y)
}

duplicated.ppx <- function(x, ...) {
  dup <- duplicated(as.data.frame(x), ...)
  return(dup)
}

anyDuplicated.ppx <- function(x, ...) {
  anyDuplicated(as.data.frame(x), ...)
}


multiplicity.ppx <- function(x) {
  mul <- multiplicity(as.data.frame(x))
  return(mul)
}

intensity.ppx <- function(X, ...) {
  if(!is.multitype(X)) {
    n <- npoints(X)
  } else {
    mks <- marks(X)
    n <- as.vector(table(mks))
    names(n) <- levels(mks)
  }
  v <- volume(domain(X))
  return(n/v)
}

grow.boxx <- function(W, left, right = left){
  W <- as.boxx(W)
  ra <- W$ranges
  d <- length(ra)
  if(any(left < 0) || any(right < 0))
    stop("values of left and right margin must be nonnegative.")
  if(length(left)==1) left <- rep(left, d)
  if(length(right)==1) right <- rep(right, d)
  if(length(left)!=d || length(right)!=d){
    stop("left and right margin must be either of length 1 or the dimension of the boxx.")
  }
  W$ranges[1,] <- ra[1,]-left
  W$ranges[2,] <- ra[2,]+right
  return(W)
}

inside.boxx <- function(..., w = NULL){
  if(is.null(w))
    stop("Please provide a boxx using the named argument w.")
  w <- as.boxx(w)
  dat <- list(...)
  if(length(dat)==1){
    dat1 <- dat[[1]]
    if(inherits(dat1, "ppx"))
      dat <- coords(dat1)
    if(inherits(dat1, "hyperframe"))
      dat <- as.data.frame(dat1)
  }
  ra <- w$ranges
  if(length(ra)!=length(dat))
    stop("Mismatch between dimension of boxx and number of coordinate vectors.")
  ## Check coord. vectors have equal length
  n <- length(dat[[1]])
  if(any(lengths(dat)!=n))
    stop("Coordinate vectors have unequal length.")
  index <- rep(TRUE, n)
  for(i in seq_along(ra)){
    index <- index & inside.range(dat[[i]], ra[[i]])
  }
  return(index)
}


spatdim <- function(X) {
  if(is.sob(X)) 2L else
  if(inherits(X, "box3")) 3 else
  if(inherits(X, "boxx")) length(X$ranges) else 
  if(is.ppx(X)) as.integer(sum(X$ctype == "spatial")) else NA_integer_
}
