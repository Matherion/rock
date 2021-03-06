#' Cleaning sources
#'
#' These function can be used to 'clean' one or more sources. Cleaning consists
#' of two operations: splitting the source at utterance markers, and conducting
#' search and replaces using regular expressions.
#'
#' When called with its default arguments, the following will happen:
#'
#' - Double periods (`..`) will be replaced with single periods (`.`)
#' - Four or more periods (`...` or `.....`) will be replaced with three periods
#' - Three or more newline characters will be replaced by one newline character (which
#' will become more, if the sentence before that character marks the end of an
#' utterance)
#' - All sentences will become separate utterances (in a semi-smart manner;
#' specifically, breaks in speaking, if represented by three periods, are not
#' considered sentence ends, wheread ellipses ("…" or unicode 2026, see the example) *are*.
#' - If there are comma's without a space following them, a space will be inserted.
#'
#' @param input For `clean_source`, either a character vector containing the text
#' of the relevant source *or* a path to a file that contains the source text;
#' for `clean_sources`, a path to a directory that contains the sources to clean.
#' @param outputFile If not `NULL`, this is the name (and path) of the file in
#' which to save the cleaned source.
#' @param replacementsPre,replacementsPost Each is a list of two-element vectors,
#' where the first element in each vector contains a regular expression to search for
#' in the source(s), and the second element contains the replacement (these are passed
#' as `perl` regular expressions; see \code{\link{regex}} for more information).
#' Instead of regular expressions, simple words or phrases can also be entered of
#' course (since those are valid regular expressions). `replacementsPre` are executed
#' before the `utteranceSplits` are applied; `replacementsPost` afterwards.
#' @param extraReplacementsPre,extraReplacementsPost To perform more replacements
#' than the default set, these can be conveniently specified in `extraReplacementsPre`
#'  and `extraReplacementsPost`. This prevents you from having to
#' manually copypaste the list of defaults to retain it.
#' @param utteranceSplits This is a vector of regular expressions that specify where to
#' insert breaks between utterances in the source(s). Such breakes are specified using
#' `utteranceMarker`.
#' @param utteranceMarker How to specify breaks between utterances in the source(s). The
#' ROCK convention is to use a newline (`\\n`).
#' @param removeNewlines Whether to remove all newline characters from the source before
#' starting to clean them.
#' @param encoding The encoding of the source(s).
#'
#' @return A character vector for `clean_source`, or a list of character vectors , for `clean_sources`.
#' @rdname cleaning_sources
#'
#' @examples exampleSource <-
#' "Do you like icecream?
#'
#'
#' Well, that depends\u2026 Sometimes, when it's..... Nice. Then I do,
#' but otherwise... not really, actually."
#'
#' ### Default settings:
#' cat(clean_source(exampleSource));
#'
#' ### First remove existing newlines:
#' cat(clean_source(exampleSource,
#'                  removeNewlines=TRUE));
#'
#' @export
clean_source <- function(input,
                         outputFile = NULL,
                         replacementsPre = list(c("([^\\.])(\\.\\.)([^\\.])",
                                                  "\\1.\\3"),
                                                c("([^\\.])(\\.\\.\\.\\.+)([^\\.])",
                                                  "\\1...\\3"),
                                                c("(\\s*\\r?\\n){3,}",
                                                  "\n")),
                         extraReplacementsPre = NULL,
                         utteranceSplits = c("([\\?\\!]+\\s?|\u2026\\s?|[[:alnum:]\\s?]\\.(?!\\.\\.)\\s?)"),
                         utteranceMarker = "\n",
                         replacementsPost = list(c("([^\\,]),([^\\s])",
                                                   "\\1, \\2")),
                         extraReplacementsPost = NULL,
                         removeNewlines = FALSE,
                         encoding = "UTF-8") {

  if (file.exists(input)) {
    res <- readLines(input,
                     encoding=encoding);

    if (removeNewlines) {
      res <-
        paste0(res, collapse="");
    } else {
      res <-
        paste0(res, collapse="\n");
    }
  } else {
    res <- input;
    if (removeNewlines) {
      res <-
        gsub("\\n", "", res);
    }
  }

  if (!is.null(extraReplacementsPre)) {
    replacementsPre <- c(replacementsPre,
                         extraReplacementsPre);
  }

  if (!is.null(extraReplacementsPost)) {
    replacementsPost <- c(replacementsPost,
                          extraReplacementsPost);
  }

  if (!is.null(replacementsPre)) {
    for (i in seq_along(replacementsPre)) {
      res <- gsub(replacementsPre[[i]][1],
                  replacementsPre[[i]][2],
                  res,
                  perl=TRUE);
    }
  }

  if (!is.null(utteranceSplits)) {
    for (i in seq_along(utteranceSplits)) {
      res <- gsub(utteranceSplits[i],
                  paste0("\\1", utteranceMarker),
                  res,
                  perl=TRUE);
    }
  }

  if (!is.null(replacementsPost)) {
    for (i in seq_along(replacementsPost)) {
      res <- gsub(replacementsPost[[i]][1],
                  replacementsPost[[i]][2],
                  res,
                  perl=TRUE);
    }
  }

  if (is.null(outputFile)) {
    return(res);
  } else {
    writeLines(text=res,
               con=con<-file(outputFile,
                             open="w",
                             encoding=encoding));
    close(con);
    invisible(res);
  }

}
