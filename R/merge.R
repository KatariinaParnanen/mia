#' Merge a subset of the rows or columns of a \code{SummarizedExperiment}
#'
#' \code{mergeRows}/\code{mergeCols} merge data on rows or columns of a
#' \code{SummarizedExperiment} as defined by a \code{factor} alongside the
#' chosen dimension. Metadata from the \code{rowData} or \code{colData} are
#' retained as defined by \code{archetype}.
#' 
#' \code{\link[SummarizedExperiment:SummarizedExperiment-class]{assay}} are 
#' agglomerated, i.e. summed up. If the assay contains values other than counts 
#' or absolute values, this can lead to meaningless values being produced. 
#'
#' @param x a \code{\link[SummarizedExperiment:SummarizedExperiment-class]{SummarizedExperiment}} or
#'   a \code{\link[TreeSummarizedExperiment:TreeSummarizedExperiment-class]{TreeSummarizedExperiment}}
#'
#' @param f A factor for merging. Must be the same length as
#'   \code{nrow(x)/ncol(x)}. Rows/Cols corresponding to the same level will be
#'   merged. If \code{length(levels(f)) == nrow(x)/ncol(x)}, \code{x} will be
#'   returned unchanged.
#'
#' @param archetype Of each level of \code{f}, which element should be regarded
#'   as the archetype and metadata in the columns or rows kept, while merging?
#'   This can be single integer value or an integer vector of the same length
#'   as \code{levels(f)}. (Default: \code{archetype = 1L}, which means the first
#'   element encountered per factor level will be kept)
#'   
#' @param mergeTree \code{TRUE} or \code{FALSE}: Should
#'   \code{rowTree()} also be merged? (Default: \code{mergeTree = FALSE})
#'
#' @param mergeRefSeq \code{TRUE} or \code{FALSE}: Should a consensus sequence
#'   be calculated? If set to \code{FALSE}, the result from \code{archetype} is
#'   returned; If set to \code{TRUE} the result from
#'   \code{\link[DECIPHER:ConsensusSequence]{DECIPHER::ConsensusSequence}} is
#'   returned. (Default: \code{mergeRefSeq = FALSE})
#'
#' @param ... Optional arguments:
#' \itemize{
#'   \item{Passed on to \code{\link[scuttle:sumCountsAcrossFeatures]{sumCountsAcrossFeatures}},
#'   with the exception of \code{subset_row}, \code{subset_col}}
#' }
#'
#' @details
#' These functions are similar to
#' \code{\link[scuttle:sumCountsAcrossFeatures]{sumCountsAcrossFeatures}}.
#' However, additional support for \code{TreeSummarizedExperiment} was added and
#' science field agnostic names were used. In addition the \code{archetype}
#' argument lets the user select how to preserve row or column data.
#'
#' For merge data of assays the function from \code{scuttle} are used.
#'
#' @name merge-methods
#' @aliases mergeRows mergeCols
#'
#' @return An object of the same class as \code{x} with the specified entries
#'   merged into one entry in all relevant components.
#'
#' @seealso
#' \code{\link[scuttle:sumCountsAcrossFeatures]{sumCountsAcrossFeatures}}
#'
#' @examples
#' data(esophagus)
#' esophagus
#' plot(rowTree(esophagus))
#' # get a factor for merging
#' f <- factor(regmatches(rownames(esophagus),
#'                        regexpr("^[0-9]*_[0-9]*",rownames(esophagus))))
#' merged <- mergeRows(esophagus,f, mergeTree = TRUE)
#' plot(rowTree(merged))
#' #
#' data(GlobalPatterns)
#' GlobalPatterns
#' merged <- mergeCols(GlobalPatterns,colData(GlobalPatterns)$SampleType)
#' merged
NULL

#' @rdname merge-methods
#' @aliases mergeFeatures
#' @export
setGeneric("mergeRows",
           signature = "x",
           function(x, f, archetype = 1L, ...)
               standardGeneric("mergeRows"))

#' @rdname merge-methods
#' @aliases mergeSamples
#' @export
setGeneric("mergeCols",
           signature = "x",
           function(x, f, archetype = 1L, ...)
               standardGeneric("mergeCols"))

#' @rdname merge-methods
#' @aliases mergeRows
#' @export
setGeneric("mergeFeatures",
           signature = "x",
           function(x, f, archetype = 1L, ...)
               standardGeneric("mergeFeatures"))

#' @rdname merge-methods
#' @aliases mergeCols
#' @export
setGeneric("mergeSamples",
           signature = "x",
           function(x, f, archetype = 1L, ...)
               standardGeneric("mergeSamples"))

.norm_f <- function(i, f, dim.type = c("rows","columns")){
    dim.type <- match.arg(dim.type)
    if(!is.character(f) && !is.factor(f)){
        stop("'f' must be a factor or character vector coercible to a ",
             "meaningful factor.",
             call. = FALSE)
    }
    if(i != length(f)){
        stop("'f' must have the same number of ",dim.type," as 'x'",
             call. = FALSE)
    }
    if(is.character(f)){
        f <- factor(f)
    }
    f
}

.norm_archetype <- function(f, archetype){
    if(length(archetype) > 1L){
        if(length(levels(f)) != length(archetype)){
            stop("length of 'archetype' must have the same length as ",
                 "levels('f')",
                 call. = FALSE)
        }
    }
    f_table <- table(f)
    if(!is.null(names(archetype))){
        if(anyNA(names(archetype)) || anyDuplicated(names(archetype))){
            stop("If 'archetype' is named, names must be non-NA and unqiue.",
                 call. = FALSE)
        }
        archetype <- archetype[names(f_table)]
    }
    if(any(f_table < archetype)){
        stop("'archetype' out of bounds for some levels of 'f'. The maximum of",
             " 'archetype' is defined as table('f')", call. = FALSE)
    }
    if(length(archetype) == 1L){
        archetype <- rep(archetype,length(levels(f)))
    }
    archetype
}

#' @importFrom S4Vectors splitAsList
.get_element_pos <- function(f, archetype){
    archetype <- as.list(archetype)
    f_pos <- seq.int(1L, length(f))
    f_pos_split <- S4Vectors::splitAsList(f_pos, f)
    f_pos <- unlist(f_pos_split[archetype])
    f_pos
}

#' @importFrom S4Vectors SimpleList
#' @importFrom scuttle sumCountsAcrossFeatures
.merge_rows <- function(x, f, archetype = 1L, 
                        average = FALSE,
                        BPPARAM = SerialParam(), 
                        ...){
    # input check
    if( !.is_a_bool(average) ){
        stop("'average' must be TRUE or FALSE.", call. = FALSE)
    }
    if(is.character(f) && length(f)==1 && f %in% colnames(rowData(x))){
        f <- factor(as.character(rowData(x)[, f]))
    }
    else if(is.character(f) && length(f)==1 && f %in% colnames(colData(x))){
        f <- factor(as.character(colData(x)[, f]))
    } else 
    {
        f <- .norm_f(nrow(x), f)  
    }
    if(length(levels(f)) == nrow(x)){
        return(x)
    }
    
    archetype <- .norm_archetype(f, archetype)
    # merge assays
    assays <- assays(x)
    mapply(.check_assays_for_merge, names(assays), assays)
    assays <- S4Vectors::SimpleList(lapply(assays,
                                           scuttle::sumCountsAcrossFeatures,
                                           ids = f, 
                                           subset.row = NULL, 
                                           subset.col = NULL,
                                           average = average,
                                           BPPARAM = BPPARAM))
    names(assays) <- names(assays(x))
    # merge to result
    x <- x[.get_element_pos(f, archetype = archetype),]
    assays(x, withDimnames = FALSE) <- assays
    # Change rownames to group names 
    rownames(x) <- rownames(assays[[1]])
    x
}

#' @importFrom scuttle sumCountsAcrossFeatures
.check_assays_for_merge <- function(assay.type, assay){
    # Check if assays include binary or negative values
    if( all(assay == 0 | assay == 1) ){
        warning(paste0("'",assay.type,"'", " includes binary values."),
                "\nAgglomeration of it might lead to meaningless values.", 
                "\nCheck the assay, and consider doing transformation again manually", 
                " with agglomerated data.",
                call. = FALSE)
    }
    if( !all( assay >= 0 | is.na(assay) ) ){
        warning(paste0("'",assay.type,"'", " includes negative values."),
                "\nAgglomeration of it might lead to meaningless values.",
                "\nCheck the assay, and consider doing transformation again manually", 
                " with agglomerated data.",
                call. = FALSE)
    }
}

#' @importFrom S4Vectors SimpleList
#' @importFrom scuttle summarizeAssayByGroup
.merge_cols <- function(x, f, archetype = 1L, ...){
    # input check
    if(is.character(f) && length(f)==1 && f %in% colnames(rowData(x))){
        f <- factor(as.character(rowData(x)[, f]))
    }
    else if(is.character(f) && length(f)==1 && f %in% colnames(colData(x))){
        f <- factor(as.character(colData(x)[, f]))
    } else 
    {
        f <- .norm_f(ncol(x), f, "columns")  
    }
    if(length(levels(f)) == ncol(x)){
        return(x)
    }
    archetype <- .norm_archetype(f, archetype)
    # merge col data
    element_pos <- .get_element_pos(f, archetype = archetype)
    col_data <- colData(x)[element_pos,,drop=FALSE]
    # merge assays
    assays <- assays(x)
    mapply(.check_assays_for_merge, names(assays), assays)
    FUN <- function(mat, ...){
        temp <- scuttle::summarizeAssayByGroup(mat,
                                               statistics = "sum",
                                               ...)
        # "sum" includes agglomerated (summed up) data
        mat <- assay(temp, "sum")
        return(mat)
    }
    assays <- S4Vectors::SimpleList(lapply(assays,
                                           FUN = FUN,
                                           ids = f, 
                                           subset.row = NULL, 
                                           subset.col = NULL,
                                           ...))
    names(assays) <- names(assays(x))
    # merge to result
    x <- x[,.get_element_pos(f, archetype = archetype)]
    assays(x, withDimnames = FALSE) <- assays
    # Change colnames to group names 
    colnames(x) <- colnames(assays[[1]])
    x
}

#' @rdname merge-methods
#' @aliases mergeFeatures
#' @export
setMethod("mergeRows", signature = c(x = "SummarizedExperiment"),
          function(x, f, archetype = 1L, ...){
              .merge_rows(x, f, archetype = archetype, ...)
          }
)

#' @rdname merge-methods
#' @aliases mergeSmaples
#' @export
setMethod("mergeCols", signature = c(x = "SummarizedExperiment"),
          function(x, f, archetype = 1L, ...){
              .merge_cols(x, f, archetype = archetype, ...)
          }
)

#' @rdname merge-methods
#' @aliases mergeRows
#' @export
setMethod("mergeFeatures", signature = c(x = "SummarizedExperiment"),
          function(x, f, archetype = 1L, ...){
              .Deprecated(old="mergeRows", new="mergeFeatures", "Now mergeRows is deprecated. Use mergeFeatures instead.")
              .merge_rows(x, f, archetype = archetype, ...)
          }
)

#' @rdname merge-methods
#' @aliases mergeCols
#' @export
setMethod("mergeSamples", signature = c(x = "SummarizedExperiment"),
          function(x, f, archetype = 1L, ...){
              .Deprecated(old="mergeCols", new="mergeSamples", "Now mergeCols is deprecated. Use mergeSamples instead.")
              .merge_cols(x, f, archetype = archetype, ...)
          }
)

.merge_tree <- function(tree, links){
    tips <- sort(setdiff(tree$edge[, 2], tree$edge[, 1]))
    drop_tip <- tips[!(tips %in% unique(links$nodeNum[links$isLeaf]))]
    oldTree <- tree
    newTree <- ape::drop.tip(oldTree, tip = drop_tip)
    track <- trackNode(oldTree)
    track <- ape::drop.tip(track, tip = drop_tip)
    #
    oldAlias <- links$nodeLab_alias
    newNode <- convertNode(tree = track, node = oldAlias)
    newAlias <- convertNode(tree = newTree, node = newNode)
    #
    list(newTree = newTree, newAlias = newAlias)
}

# Merge trees, MARGIN specifies if trees are rowTrees or colTrees
.merge_trees <- function(x, mergeTree, MARGIN){
    # Get rowtrees or colTrees based on MARGIN
    if( MARGIN == 1 ){
        trees <- x@rowTree
        links <- rowLinks(x)
    } else{
        trees <- x@colTree
        links <- colLinks(x)
    }
    # If trees exist and mergeTree is TRUE
    if(!is.null(trees) && mergeTree){
        # Loop over trees and replace them one by one
        for( i in seq_len(length(trees)) ){
            # Get tree
            tree <- trees[[i]]
            # Get the name of the tree
            tree_name <- names(trees)[[i]]
            # Subset links by taking only those rows that are included in tree
            links_sub <- links[ links$whichTree == tree_name, , drop = FALSE ]
            # Merge tree
            tmp <- .merge_tree(tree, links_sub)
            # Based on MARGIN, replace ith rowTree or colTree
            if( MARGIN == 1 ){
                x <- changeTree(x = x,
                                rowTree = tmp$newTree,
                                rowNodeLab = tmp$newAlias,
                                whichRowTree = i
                )
            } else{
                x <- changeTree(x = x,
                                colTree = tmp$newTree,
                                colNodeLab = tmp$newAlias,
                                whichColTree = i
                )
            }
        }
    }
    return(x)
}

#' @importFrom Biostrings DNAStringSetList
.merge_refseq_list <- function(sequences_list, f, names, ...){
    threshold <- list(...)[["threshold"]]
    if(is.null(threshold)){
        threshold <- 0.05
    }
    if(!is(sequences_list,"DNAStringSetList")){
        return(.merge_refseq(sequences_list, f, names, threshold))
    }
    names <- names(sequences_list)
    seqs <- DNAStringSetList(lapply(sequences_list, .merge_refseq, f, names,
                                    threshold))
    names(seqs) <- names
    seqs
}

#' @importFrom Biostrings DNAStringSetList
#' @importFrom DECIPHER ConsensusSequence
.merge_refseq <- function(sequences, f, names, threshold){
    sequences <- split(sequences,f)
    seq <- unlist(DNAStringSetList(lapply(sequences, ConsensusSequence,
                                          threshold = threshold)))
    seq
}

#' @rdname merge-methods
#' @importFrom ape keep.tip
#' @export
setMethod("mergeRows", signature = c(x = "TreeSummarizedExperiment"),
          function(x, f, archetype = 1L, mergeTree = FALSE, mergeRefSeq = FALSE, ...){
              # input check
              if(!.is_a_bool(mergeTree)){
                  stop("'mergeTree' must be TRUE or FALSE.", call. = FALSE)
              }
              if(!.is_a_bool(mergeRefSeq)){
                  stop("'mergeRefSeq' must be TRUE or FALSE.", call. = FALSE)
              }
              # for optionally merging referenceSeq
              refSeq <- NULL
              if(mergeRefSeq){
                  refSeq <- referenceSeq(x)
              }
              #
              x <- callNextMethod(x, f, archetype = 1L, ...)
              # optionally merge rowTree
              x <- .merge_trees(x, mergeTree, 1)
              # optionally merge referenceSeq
              if(!is.null(refSeq)){
                  referenceSeq(x) <- .merge_refseq_list(refSeq, f, rownames(x), ...)
              }
              x
          }
)

#' @rdname merge-methods
#' @importFrom ape keep.tip
#' @export
setMethod("mergeCols", signature = c(x = "TreeSummarizedExperiment"),
          function(x, f, archetype = 1L, mergeTree = FALSE, ...){
              # input check
              if(!.is_a_bool(mergeTree)){
                  stop("'mergeTree' must be TRUE or FALSE.", call. = FALSE)
              }
              #
              x <- callNextMethod(x, f, archetype = 1L, ...)
              # optionally merge colTree
              x <- .merge_trees(x, mergeTree, 2)
              return(x)
          }
)

#' @rdname merge-methods
#' @importFrom ape keep.tip
#' @aliases mergeRows
#' @export
setMethod("mergeFeatures", signature = c(x = "TreeSummarizedExperiment"),
          function(x, f, archetype = 1L, mergeTree = FALSE, mergeRefSeq = FALSE, ...){
             .Deprecated(old="mergeRows", new="mergeFeatures", "Now mergeRows is deprecated. Use mergeFeatures instead.")
             x <- mergeRows(x = x, f = f, archetype = 1L, mergeTree = mergeTree, mergeRefSeq = mergeRefSeq, ...)
              return(x)
          }
)

#' @rdname merge-methods
#' @importFrom ape keep.tip
#' @aliases mergeCols
#' @export
setMethod("mergeSamples", signature = c(x = "TreeSummarizedExperiment"),
          function(x, f, archetype = 1L, mergeTree = FALSE, ...){
              .Deprecated(old="mergeCols", new="mergeSamples", "Now mergeCols is deprecated. Use mergeSamples instead.")
              x <- mergeCols(x, f, archetype = 1L, mergeTree =mergeTree, ...)
              return(x)
          }
)
