#' Summarizing microbiome data
#'
#' To query a \code{SummarizedExperiment} for interesting features, several
#' functions are available.
#'
#' @param x A
#'  \code{\link[SummarizedExperiment:SummarizedExperiment-class]{SummarizedExperiment}} object.
#'
#' @param top Numeric value, how many top taxa to return. Default return top
#'   five taxa.
#'
#' @param method Specify the method to determine top taxa. Either sum, mean,
#'   median or prevalence. Default is 'mean'.
#'
#' @param assay.type A \code{character} value to select an
#'   \code{\link[SummarizedExperiment:SummarizedExperiment-class]{assayNames}} 
#'   
#' @param assay_name a single \code{character} value for specifying which
#'   assay to use for calculation.
#'   (Please use \code{assay.type} instead. At some point \code{assay_name}
#'   will be disabled.)
#'   
#' @param na.rm For \code{getTopFeatures} logical argument for calculation method 
#'              specified to argument \code{method}. Default is TRUE. 
#'
#' @param ... Additional arguments passed, e.g., to getPrevalence:
#'    \itemize{
#'        \item{\code{sort}}{A single boolean value for selecting 
#'        whether to sort taxa in alphabetical order or not. Enabled in functions
#'        \code{getUniqueFeatures}, and \code{getTopFeatures}.
#'        (By default: \code{sort = FALSE})}
#'        \item{\code{na.rm}}{A single boolean value for selecting 
#'        whether to remove missing values or not. Enabled in functions
#'        \code{getUniqueFeatures}, and \code{getTopFeatures}.
#'        (By default: \code{na.rm = FALSE})}
#'    }
#'    
#' @details
#' The \code{getTopFeatures} extracts the most \code{top} abundant \dQuote{FeatureID}s
#' in a \code{\link[SummarizedExperiment:SummarizedExperiment-class]{SummarizedExperiment}}
#' object.
#'
#' The \code{getUniqueFeatures} is a basic function to access different taxa at a
#' particular taxonomic rank.
#'
#' @return
#' The \code{getTopFeatures} returns a vector of the most \code{top} abundant
#' \dQuote{FeatureID}s
#'
#' @seealso
#' \code{\link[=getPrevalence]{getPrevalentFeatures}}
#'
#' @name summaries
#'
#' @author
#' Leo Lahti, Tuomas Borman and Sudarshan A. Shetty
#'
#' @examples
#' data(GlobalPatterns)
#' top_taxa <- getTopFeatures(GlobalPatterns,
#'                        method = "mean",
#'                        top = 5,
#'                        assay.type = "counts")
#' top_taxa
#' 
#' # Use 'detection' to select detection threshold when using prevalence method
#' top_taxa <- getTopFeatures(GlobalPatterns,
#'                        method = "prevalence",
#'                        top = 5,
#'                        assay_name = "counts",
#'                        detection = 100)
#' top_taxa
#'                        
#' # Top taxa os specific rank
#' getTopFeatures(agglomerateByRank(GlobalPatterns,
#'                              rank = "Genus",
#'                              na.rm = TRUE))
#'
#' # Gets the overview of dominant taxa
#' dominant_taxa <- countDominantFeatures(GlobalPatterns,
#'                                    rank = "Genus")
#' dominant_taxa
#'
#' # With group, it is possible to group observations based on specified groups
#' # Gets the overview of dominant taxa
#' dominant_taxa <- countDominantFeatures(GlobalPatterns,
#'                                    rank = "Genus",
#'                                    group = "SampleType",
#'                                    na.rm = TRUE)
#'
#' dominant_taxa
#'
#' # Get an overview of sample and taxa counts
#' summary(GlobalPatterns, assay_name= "counts")
#'
#' # Get unique taxa at a particular taxonomic rank
#' # sort = TRUE means that output is sorted in alphabetical order
#' # With na.rm = TRUE, it is possible to remove NAs
#' # sort and na.rm can also be used in function getTopFeatures
#' getUniqueFeatures(GlobalPatterns, "Phylum", sort = TRUE)
#'
NULL

#' @rdname summaries
#' @aliases getTopTaxa
#' @export
setGeneric("getTopFeatures", signature = "x",
           function(x, top= 5L, method = c("mean","sum","median"),
                    assay.type = assay_name, assay_name = "counts", 
                    na.rm = TRUE, ...)
               standardGeneric("getTopFeatures"))

.check_max_taxa <- function(x, top, assay.type){
    if(!is.numeric(top) || as.integer(top) != top){
        stop("'top' must be integer value", call. = FALSE)
    }
    if(top > nrow(assay(x,assay.type))){
        stop("'top' must be <= nrow(x)", call. = FALSE)
    }
}

#' @rdname summaries
#'
#' @importFrom DelayedMatrixStats rowSums2 rowMeans2 rowMedians
#' @importFrom utils head
#' 
#' @aliases getTopTaxa
#'
#' @export
setMethod("getTopFeatures", signature = c(x = "SummarizedExperiment"),
    function(x, top = 5L, method = c("mean","sum","median","prevalence"),
             assay.type = assay_name, assay_name = "counts", 
             na.rm = TRUE, ...){
        # input check
        method <- match.arg(method, c("mean","sum","median","prevalence"))
        # check max taxa
        .check_max_taxa(x, top, assay.type)
        # check assay
        .check_assay_present(assay.type, x)
        #
        if(method == "prevalence"){
            taxs <- getPrevalence(assay(x, assay.type), sort = TRUE,
                                  include_lowest = TRUE, ...)
            # If there are taxa with prevalence of 0, remove them
            taxs <- taxs[ taxs > 0 ]
        } else {
            taxs <- switch(method,
                           mean = rowMeans2(assay(x, assay.type), na.rm = na.rm),
                           sum = rowSums2(assay(x, assay.type), na.rm = na.rm),
                           median = rowMedians(assay(x, assay.type)), na.rm = na.rm)
            names(taxs) <- rownames(assay(x))
            taxs <- sort(taxs,decreasing = TRUE)
        }
        names <- head(names(taxs), n = top)
        # Remove NAs and sort if specified
        names <- .remove_NAs_and_sort(names, ... )
        return(names)
    }
)

#' @rdname summaries
#' @aliases getTopFeatures
#' @export
setGeneric("getTopTaxa", signature = c("x"),
           function(x, ...) 
               standardGeneric("getTopTaxa"))

#' @rdname summaries
#' @aliases getTopFeatures
#' @export
setMethod("getTopTaxa", signature = c(x = "SummarizedExperiment"),
    function(x, ...){
        .Deprecated(old ="getTopTaxa", new = "getTopFeatures", msg = "The 'getTopTaxa' function is deprecated. Use 'getTopFeatures' instead.")
        getTopFeatures(x, ...)
    }
)

#' @rdname summaries
#'
#' @param rank A single character defining a taxonomic rank. Must be a value of
#' the output of \code{taxonomyRanks()}.
#'
#' @return
#' The \code{getUniqueFeatures} returns a vector of unique taxa present at a
#' particular rank
#' 
#' @aliases getUniqueTaxa
#' 
#' @export
setGeneric("getUniqueFeatures",
           signature = c("x"),
           function(x, ...)
               standardGeneric("getUniqueFeatures"))

#' @rdname summaries
#' @aliases getUniqueTaxa
#' @export
setMethod("getUniqueFeatures", signature = c(x = "SummarizedExperiment"),
    function(x, rank = NULL, ...){
        .check_taxonomic_rank(rank, x)
        names <- unique(rowData(x)[,rank])
        # Remove NAs and sort if specified
        names <- .remove_NAs_and_sort(names, ... )
        return(names)
    }
)

#' @rdname summaries
#' @aliases getUniqueFeatures
#' @export
setGeneric("getUniqueTaxa", signature = c("x"),
           function(x, ...) 
               standardGeneric("getUniqueTaxa"))

#' @rdname summaries
#' @aliases getUniqueFeatures
#' @export
setMethod("getUniqueTaxa", signature = c(x = "SummarizedExperiment"),
    function(x, ...){
        getUniqueFeatures(x, ...)
    }
)


#' @rdname summaries
#'
#' @param group With group, it is possible to group the observations in an
#'   overview. Must be one of the column names of \code{colData}.
#'   
#' @param name The column name for the features. The default is 'dominant_taxa'.
#'
#' @param ... Additional arguments passed on to \code{agglomerateByRank()} when
#'   \code{rank} is specified for \code{countDominantFeatures}.
#'
#' @details
#' \code{countDominantFeatures} returns information about most dominant
#' taxa in a tibble. Information includes their absolute and relative
#' abundances in whole data set.
#'
#'
#' @return
#' The \code{countDominantFeatures} returns an overview in a tibble. It contains dominant taxa
#' in a column named \code{*name*} and its abundance in the data set.
#' 
#' @export
setGeneric("countDominantFeatures",signature = c("x"),
           function(x, group = NULL, name = "dominant_taxa", ...)
               standardGeneric("countDominantFeatures"))


#' @rdname summaries
#' @aliases countDominantTaxa
#' @export
setMethod("countDominantFeatures", signature = c(x = "SummarizedExperiment"),
    function(x, group = NULL, name = "dominant_taxa", ...){
        # Input check
        # group check
        if(!is.null(group)){
            if(isFALSE(any(group %in% colnames(colData(x))))){
                stop("'group' variable must be in colnames(colData(x))",
                     call. = FALSE)
            }
        }
        # name check
        if(!.is_non_empty_string(name)){
            stop("'name' must be a non-empty single character value.",
                 call. = FALSE)
        }
        
        # Adds dominant taxa to colData
        dominant_taxa <- perSampleDominantTaxa(x, ...)
        data <- colData(x)
        # If the length of dominant taxa is not equal to number of rows, then add rows
        # because there are multiple dominant taxa
        if(length(dominant_taxa) > nrow(data) ){
            # Get the order
            order <- unique(names(dominant_taxa))
            # there are multiple dominant taxa in one sample (counts are equal), length
            # of dominant is greater than rows in colData. --> create a list that contain
            # dominant taxa, and is as long as there are rows in colData
            dominant_taxa_list <- split(dominant_taxa, rep(names(dominant_taxa), lengths(dominant_taxa)) )
            # Order the data
            dominant_taxa_list <- dominant_taxa_list[order]
            data <- data[rep(seq_len(nrow(data)), lengths(dominant_taxa_list)), ]
        }
        # Add dominant taxa to data
        colname <- "dominant_taxa"
        data[[colname]] <- dominant_taxa
        # Gets an overview
        tab <- .tally_col_data(data, group, colname, ...)
        colnames(tab)[colnames(tab) == colname] <- name
        return(tab)
    }
)


#' @rdname summaries
#' @aliases countDominantFeatures
#' @export
setGeneric("countDominantTaxa", signature = c("x"),
           function(x, ...)
               standardGeneric("countDominantTaxa"))

#' @rdname summaries
#' @aliases countDominantFeatures
#' @export
setMethod("countDominantTaxa", signature = c(x = "SummarizedExperiment"),
    function(x, ...){
        .Deprecated(old ="countDominantTaxa", new = "countDominantFeatures", msg = "The 'countDominantTaxa' function is deprecated. Use 'countDominantFeatures' instead.")
        countDominantFeatures(x, ...)
    }
)


################################ HELP FUNCTIONS ################################

#' @importFrom S4Vectors as.data.frame
#' @importFrom dplyr n desc tally group_by arrange mutate
.tally_col_data <- function(data, group, colname, digits = NULL, ...){
    # Convert data to data.frame
    data <- as.data.frame(data)
    
    # 
    # # If there are multiple dominant taxa in one sample, the column is a list.
    # # Convert it so that there are multiple rows for sample and each row contains
    # # one dominant taxa.
    # if( is.list(data[[name]]) ){
    #     # Get dominant taxa as a vector
    #     dominant_taxa <- unlist(data[[name]])
    #     # Create additional rows
    #     data <- data[rep(seq_len(nrow(data)), lengths(data[[name]])), ]
    #     # Add dominant taxa
    #     data[[name]] <- dominant_taxa
    # }
    
    # Creates a tibble that contains number of times that a column of "name"
    # is present in samples and relative portion of samples where they
    # present.
    
    # digits check
    if(!is.null(digits)){
        if(!is.numeric(digits)) {
            stop("'digits' must be numeric", call. = FALSE)
        } 
    }
    
    if (is.null(group)) {
        colname <- sym(colname)
        data <- data %>%
            group_by(!!colname)
    } else {
        group <- sym(group)
        colname <- sym(colname)
        data <- data %>%
            group_by(!!group, !!colname)
    }
    tallied_data <- data %>%
        tally() %>%
        mutate(
            rel_freq = n / sum(n)
        ) %>%
        arrange(desc(n))
    if(!is.null(digits)) {
        tallied_data["rel_freq"] <- round(tallied_data["rel_freq"], digits) 
    }
    return(tallied_data)
}

#' @rdname summaries
#'
#' @param object A
#'  \code{\link[SummarizedExperiment:SummarizedExperiment-class]{SummarizedExperiment}} object.
#'
#' @param assay.type a \code{character} value to select an
#'   \code{\link[SummarizedExperiment:SummarizedExperiment-class]{assayNames}}
#'   By default it expects count data.
#'
#' @details
#' The \code{summary} will return a summary of counts for all samples and
#' features in
#' \code{\link[SummarizedExperiment:SummarizedExperiment-class]{SummarizedExperiment}}
#' object.
#'
#' @return
#' The \code{summary} returns a list with two \code{tibble}s
#'
#' @seealso
#' \code{\link[scuttle:perCellQCMetrics]{perCellQCMetrics}},
#' \code{\link[scuttle:perFeatureQCMetrics]{perFeatureQCMetrics}},
#' \code{\link[scuttle:addPerCellQC]{addPerCellQC}},
#' \code{\link[scuttle:addPerFeatureQC]{addPerFeatureQC}},
#' \code{\link[scuttle:quickPerCellQC]{quickPerCellQC}}
#'
#' @export
setMethod("summary", signature = c(object = "SummarizedExperiment"),
    function(object, assay.type = assay_name, assay_name = "counts"){

        # Specify assay names for user
        message("Following assays detected: ", call. = FALSE)
        message(assayNames(object))
        # Check if assay name is specified
        #.check_abund_assay(object,
        #                   assay_name = assay_name)
        .check_assay_present(assay.type = assay.type, object)

        # check if NA in assay
        .check_NAs_assay_counts(object, assay.type)
        # check if counts
        .check_fraction_or_negative_values(object, assay.type)
        sample.summary <- .get_summary_col_data(object, assay.type)
        feature.summary <- .get_summary_row_data(object, assay.type)
        return(list("samples" = sample.summary, "features" = feature.summary))
    }
)

################################ HELP FUNCTIONS summary ####################

#' @importFrom DelayedMatrixStats colSums2
#' @importFrom stats sd median
#' @importFrom tibble tibble
.get_summary_col_data <- function(x, assay.type){
    # should check and extract assay
    assay.x <- .get_assay(x, assay.type)
    summary_col_data <- tibble(total_counts = sum(colSums2(assay.x)),
                               min_counts = min(colSums2(assay.x)),
                               max_counts = max(colSums2(assay.x)),
                               median_counts = median(colSums2(assay.x)),
                               mean_counts = mean(colSums2(assay.x)),
                               stdev_counts = sd(colSums2(assay.x)))
    return(summary_col_data)
}

#' @importFrom DelayedMatrixStats colSums2
#' @importFrom tibble tibble
.get_summary_row_data <- function(x, assay.type){
    # Should check and extract assay
    # Internal from splitByRanks
    assay.x <- .get_assay(x, assay.type)
    summary_row_data <- tibble(total = nrow(assay.x),
                               singletons = .get_singletons(assay.x),
                               per_sample_avg = mean(colSums2(assay.x != 0)))
    return(summary_row_data)
}

# Get singletons from assay matrix
#' @importFrom DelayedMatrixStats rowSums2
#' @importFrom tibble tibble
.get_singletons<-function(x){
    length(rowSums2(x)[rowSums2(x) == 1])
}

# Check if values in assay are fractions or or negative values
#' @importFrom DelayedMatrixStats colSums2
.check_fraction_or_negative_values <- function(x, assay.type){
    assay.x <- .get_assay(x, assay.type)
    if(any(colSums2(assay.x) < 1) | any(colSums2(assay.x) < 0)){
        stop("There are samples that sum to 1 or less counts. ",
             "Try to supply raw counts",
             call. = FALSE)
    }
}

# Remove NAs and order in alphabetical order
.remove_NAs_and_sort <- function(names, sort = FALSE, na.rm = FALSE, ...){
    # Check sort
    if( !.is_a_bool(sort) ){
        stop("'sort' must be a boolean value.", call. = FALSE)
    }
    # Check na.rm
    if( !.is_a_bool(na.rm) ){
        stop("'na.rm' must be a boolean value.", call. = FALSE)
    }
    # Remove NAs if specified
    if( na.rm ){
        names <- names[ !is.na(names) ]
    }
    # Sort in alphabetical order if sort is TRUE
    if( sort ){
        names <- sort(names, na.last = TRUE)
    }
    return(names)
}

# Check NAs in assay, used when specifically when counts are expected
.check_NAs_assay_counts <- function(x, assay.type){
    assay.x <- .get_assay(x, assay.type)
    if(any(is.na(assay.x))) {
        stop(paste0("There are samples with NAs in 'assay': ", assay.type),
             " . This function is limited to sequencing data only. ",
             "Where raw counts do not usually have NAs. ",
             "Try to supply raw counts",
             call. = FALSE)
    }
}

