#' @export
#' @title fit a flextable to a maximum width
#' @description decrease font size for each cell incrementally until
#' it fits a given max_width.
#' @param x flextable object
#' @param max_width maximum width to fit in inches
#' @param inc the font size decrease for each step
#' @param max_iter maximum iterations
#' @examples
#' ft <- qflextable(head(mtcars))
#' ft <- padding(ft, padding = 0, part = "all")
#' fit_to_width(ft, max_width = 6)
#' @family flextable dimensions
fit_to_width <- function(x, max_width, inc = 1L, max_iter = 20 ){
  go <- TRUE
  while(go){
    fdim <- flextable_dim(x)

    if( fdim$widths > max_width){
      # message("minimimising")
      # browser()
      if( nrow_part(x, part = "body") > 0 )
        x$body$styles$text$font.size$data[] <- x$body$styles$text$font.size$data - inc
      if( nrow_part(x, part = "footer") > 0 )
        x$footer$styles$text$font.size$data[] <- x$footer$styles$text$font.size$data - inc
      if( nrow_part(x, part = "header") > 0 )
        x$header$styles$text$font.size$data[] <- x$header$styles$text$font.size$data - inc

      x <- autofit(x, add_w = 0.0, add_h = 0.0)
    } else go <- FALSE
  }
  x
}


#' @export
#' @title Set flextable columns width
#' @description control columns width
#' @param x flextable object
#' @param j columns selection
#' @param width width in inches
#' @details
#' Heights are not used when flextable is been rendered into HTML.
#' @examples
#'
#' ft <- flextable(iris)
#' ft <- width(ft, width = 1)
#'
#' @family flextable dimensions
width <- function(x, j = NULL, width){

  j <- get_columns_id(x[["body"]], j )

  stopifnot(length(j)==length(width) || length(width) == 1)

  if( length(width) == 1 ) width <- rep(width, length(j))

  x$header$colwidths[j] <- width
  x$footer$colwidths[j] <- width
  x$body$colwidths[j] <- width

  x
}

#' @export
#' @title Set flextable rows height
#' @description control rows height for a part
#' of the flextable.
#' @param x flextable object
#' @param i rows selection
#' @param height height in inches
#' @param part partname of the table
#' @examples
#'
#' ft <- flextable(iris)
#' ft <- height(ft, height = .3)
#'
#' @family flextable dimensions
height <- function(x, i = NULL, height, part = "body"){

  part <- match.arg(part, c("body", "header", "footer"), several.ok = FALSE )

  if( inherits(i, "formula") && any( c("header", "footer") %in% part ) ){
    stop("formula in argument i cannot adress part 'header' or 'footer'.")
  }

  if( nrow_part(x, part ) < 1 ) return(x)

  i <- get_rows_id(x[[part]], i )
  if( !(length(i) == length(height) || length(height) == 1)){
    stop("height should be of length 1 or ", length(i))
  }

  x[[part]]$rowheights[i] <- height

  x
}

#' @export
#' @rdname height
#' @section height_all:
#' \code{height_all} is a convenient function for
#' setting the same height to all rows (selected
#' with argument \code{part}).
#' @examples
#'
#' ft <- flextable(iris)
#' ft <- height_all(ft, height = .3)
#'
height_all <- function(x, height, part = "all"){

  part <- match.arg(part, c("body", "header", "footer", "all"), several.ok = FALSE )
  if( length(height) != 1 || !is.numeric(height) || height < 0.0 ){
    stop("height should be a single positive numeric value", call. = FALSE)
  }

  if( "all" %in% part ){
    for(i in c("body", "header", "footer") ){

      x <- height_all(x, height = height, part = i)
    }
  }

  if( nrow_part(x, part) > 0 ){
    i <- seq_len(nrow(x[[part]]$dataset))
    x[[part]]$rowheights[i] <- height
  }

  x
}

#' @export
#' @title width and height of a flextable object
#' @description Returns the width, height and
#' aspect ratio of a flextable in a named list.
#' The width and height are in inches. The aspect ratio
#' is the ratio corresponding to \code{height/width}.
#'
#' Names of the list are \code{width}, \code{height} and \code{aspect_ratio}.
#' @param x a flextable object
#' @examples
#' ft <- flextable(head(iris))
#' flextable_dim(ft)
#' ft <- autofit(ft)
#' flextable_dim(ft)
#' @family flextable dimensions
flextable_dim <- function(x){
  dims <- lapply( dim(x), sum)
  dims$aspect_ratio <- dims$height / dims$width
  dims
}


#' @title Get widths and heights of flextable
#' @description returns widths and heights for each table columns and rows.
#' Values are expressed in inches.
#' @param x flextable object
#' @family flextable dimensions
#' @examples
#' ft <- flextable(head(iris))
#' dim(ft)
#' @export
dim.flextable <- function(x){
  max_widths <- list()
  max_heights <- list()
  for(j in c("header", "body", "footer")){
    if( nrow_part(x, j ) > 0 ){
      max_widths[[j]] <- x[[j]]$colwidths
      max_heights[[j]] <- x[[j]]$rowheights
    }
  }

  mat_widths <- do.call("rbind", max_widths)
  if( is.null( mat_widths ) ){
    out_widths <- numeric(0)
  } else {
    out_widths <- apply( mat_widths, 2, max )
    names(out_widths) <- x$col_keys
  }

  out_heights <- as.double(unlist(max_heights))
  list(widths = out_widths, heights = out_heights )
}

#' @export
#' @title Calculate pretty dimensions
#' @description return minimum estimated widths and heights for
#' each table columns and rows in inches.
#' @param x flextable object
#' @param part partname of the table (one of 'all', 'body', 'header' or 'footer')
#' @examples
#' ft <- flextable(mtcars)
#' \donttest{dim_pretty(ft)}
#' @family flextable dimensions
dim_pretty <- function( x, part = "all" ){

  part <- match.arg(part, c("all", "body", "header", "footer"), several.ok = FALSE )
  if( "all" %in% part ){
    part <- c("header", "body", "footer")
  }
  dimensions <- list()
  for(j in part){
    if( nrow_part(x, j ) > 0 ){
      dimensions[[j]] <- optimal_sizes(x[[j]])
    } else {
      dimensions[[j]] <- list(widths = rep(0, length(x$col_keys) ),
           heights = numeric(0) )
    }
  }
  widths <- lapply( dimensions, function(x) x$widths )
  widths <- as.numeric(apply( do.call(rbind, widths), 2, max, na.rm = TRUE ))

  heights <- lapply( dimensions, function(x) x$heights )
  heights <- as.numeric(do.call(c, heights))


  list(widths = widths, heights = heights)
}



#' @export
#' @title Adjusts cell widths and heights
#' @description compute and apply optimized widths and heights.
#' This function is to be used when the table widths and heights
#' should automatically be adjusted to fit the size of the content.
#'
#' @param x flextable object
#' @param add_w extra width to add in inches
#' @param add_h extra height to add in inches
#' @examples
#' ft <- flextable(mtcars)
#' \donttest{ft <- autofit(ft)}
#' ft
#' @family flextable dimensions
autofit <- function(x, add_w = 0.1, add_h = 0.1 ){

  stopifnot(inherits(x, "flextable") )
  dimensions_ <- dim_pretty(x)
  names(dimensions_$widths) <- x$col_keys

  parts <- c("header", "body", "footer")
  nrows <- lapply(parts, function(j){
    nrow_part(x, j )
  } )
  heights <- list(lengths = unlist(nrows), values = parts )
  class(heights) <- "rle"
  heights <- data.frame( part = inverse.rle(heights),
                         height = dimensions_$heights + add_h,
                         stringsAsFactors = FALSE)
  heights <- split(heights$height, heights$part)

  for(j in names(heights)){
    x[[j]]$colwidths <- dimensions_$widths + add_w
    x[[j]]$rowheights <- heights[[j]]
  }
  x
}




#' @importFrom gdtools m_str_extents
optimal_sizes <- function( x ){

  sizes <- text_metric(x)
  sizes$col_id <- factor(sizes$col_id, levels = x$col_keys)
  sizes <- sizes[order(sizes$col_id, sizes$row_id ), ]
  widths <- as_wide_matrix_(data = sizes[, c("col_id", "width", "row_id")], idvar = "row_id", timevar = "col_id")
  dimnames(widths)[[2]] <- gsub("^width\\.", "", dimnames(widths)[[2]])
  heights <- as_wide_matrix_(data = sizes[, c("col_id", "height", "row_id")], idvar = "row_id", timevar = "col_id")
  dimnames(heights)[[2]] <- gsub("^height\\.", "", dimnames(heights)[[2]])

  par_dim <- dim_paragraphs(x)
  widths <- widths + par_dim$widths
  heights <- heights + par_dim$heights

  widths[x$spans$rows<1] <- 0
  widths[x$spans$columns<1] <- 0
  heights[x$spans$rows<1] <- 0
  heights[x$spans$columns<1] <- 0

  cell_dim <- dim_cells(x)
  widths <- widths + cell_dim$widths
  heights <- heights + cell_dim$heights

  list(widths = apply(widths, 2, max, na.rm = TRUE),
       heights = apply(heights, 1, max, na.rm = TRUE) )
}

# utils ----
#' @importFrom stats reshape
as_wide_matrix_ <- function(data, idvar, timevar = "col_key"){
  x <- reshape(data = data, idvar = idvar, timevar = timevar, direction = "wide")
  x[[idvar]] <- NULL
  as.matrix(x)
}


dim_paragraphs <- function(x){
  par_dim <- as.data.frame(x$styles$pars)
  par_dim$width <- as.vector(x$styles$pars[,,"padding.right"] + x$styles$pars[,,"padding.left"]) * (4/3) / 72
  par_dim$height <- as.vector(x$styles$pars[,,"padding.top"] + x$styles$pars[,,"padding.bottom"]) * (4/3) / 72
  selection_ <- c("row_id", "col_id", "width", "height")
  par_dim[, selection_]

  list( widths = as_wide_matrix_( par_dim[,c("col_id", "width", "row_id")], idvar = "row_id", timevar = "col_id" ),
        heights = as_wide_matrix_( par_dim[,c("col_id", "height", "row_id")], idvar = "row_id", timevar = "col_id" )
  )
}

dim_cells <- function(x){
  cell_dim <- as.data.frame(x$styles$cells)
  cell_dim$width <- as.vector(x$styles$cells[,,"margin.right"] + x$styles$cells[,,"margin.left"]) * (4/3) / 72
  cell_dim$height <- as.vector(x$styles$cells[,,"margin.top"] + x$styles$cells[,,"margin.bottom"]) * (4/3) / 72
  selection_ <- c("row_id", "col_id", "width", "height")
  cell_dim <- cell_dim[, selection_]

  cellwidths <- as_wide_matrix_( cell_dim[,c("col_id", "width", "row_id")], idvar = "row_id", timevar = "col_id" )
  cellheights <- as_wide_matrix_( cell_dim[,c("col_id", "height", "row_id")], idvar = "row_id", timevar = "col_id")

  list( widths = cellwidths, heights = cellheights )
}


text_metric <- function( x ){
  txt_data <- fortify_content(x$content, default_chunk_fmt = x$styles$text)

  widths <- txt_data$width
  heights <- txt_data$height
  txt_data$width <- NULL
  txt_data$height <- NULL

  fontsize <- txt_data$font.size
  fontsize[!(txt_data$vertical.align %in% "baseline")] <- fontsize[!(txt_data$vertical.align %in% "baseline")]/2
  str_extents_ <- m_str_extents(txt_data$txt, fontname = txt_data$font.family,
                fontsize = fontsize, bold = txt_data$bold,
                italic = txt_data$italic) / 72
  str_extents_[,1] <- ifelse(is.na(str_extents_[,1]) & !is.null(widths), widths, str_extents_[,1] )
  str_extents_[,2] <- ifelse(is.na(str_extents_[,2]) & !is.null(heights), heights, str_extents_[,2] )
  dimnames(str_extents_) <- list(NULL, c("width", "height"))
  txt_data <- cbind( txt_data, str_extents_ )

  selection_ <- c("row_id", "col_id", "seq_index", "width", "height")
  txt_data <- txt_data[, selection_]
  setDT(txt_data)
  txt_data <- txt_data[, c(list(width=sum(width, na.rm = TRUE), height = max(height, na.rm = TRUE) )),
                         by= c("row_id", "col_id") ]
  setDF(txt_data)
  txt_data
}


