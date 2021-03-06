% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/clean_source.R
\name{clean_source}
\alias{clean_source}
\title{Cleaning sources}
\usage{
clean_source(input, outputFile = NULL,
  replacementsPre = list(c("([^\\\\.])(\\\\.\\\\.)([^\\\\.])",
  "\\\\1.\\\\3"), c("([^\\\\.])(\\\\.\\\\.\\\\.\\\\.+)([^\\\\.])",
  "\\\\1...\\\\3"), c("(\\\\s*\\\\r?\\\\n){3,}", "\\n")),
  extraReplacementsPre = NULL,
  utteranceSplits = c("([\\\\?\\\\!]+\\\\s?|…\\\\s?|[[:alnum:]\\\\s?]\\\\.(?!\\\\.\\\\.)\\\\s?)"),
  utteranceMarker = "\\n",
  replacementsPost = list(c("([^\\\\,]),([^\\\\s])", "\\\\1, \\\\2")),
  extraReplacementsPost = NULL, removeNewlines = FALSE,
  encoding = "UTF-8")
}
\arguments{
\item{input}{For \code{clean_source}, either a character vector containing the text
of the relevant source \emph{or} a path to a file that contains the source text;
for \code{clean_sources}, a path to a directory that contains the sources to clean.}

\item{outputFile}{If not \code{NULL}, this is the name (and path) of the file in
which to save the cleaned source.}

\item{replacementsPre, replacementsPost}{Each is a list of two-element vectors,
where the first element in each vector contains a regular expression to search for
in the source(s), and the second element contains the replacement (these are passed
as \code{perl} regular expressions; see \code{\link{regex}} for more information).
Instead of regular expressions, simple words or phrases can also be entered of
course (since those are valid regular expressions). \code{replacementsPre} are executed
before the \code{utteranceSplits} are applied; \code{replacementsPost} afterwards.}

\item{extraReplacementsPre, extraReplacementsPost}{To perform more replacements
than the default set, these can be conveniently specified in \code{extraReplacementsPre}
and \code{extraReplacementsPost}. This prevents you from having to
manually copypaste the list of defaults to retain it.}

\item{utteranceSplits}{This is a vector of regular expressions that specify where to
insert breaks between utterances in the source(s). Such breakes are specified using
\code{utteranceMarker}.}

\item{utteranceMarker}{How to specify breaks between utterances in the source(s). The
ROCK convention is to use a newline (\code{\\n}).}

\item{removeNewlines}{Whether to remove all newline characters from the source before
starting to clean them.}

\item{encoding}{The encoding of the source(s).}
}
\value{
A character vector for \code{clean_source}, or a list of character vectors , for \code{clean_sources}.
}
\description{
These function can be used to 'clean' one or more sources. Cleaning consists
of two operations: splitting the source at utterance markers, and conducting
search and replaces using regular expressions.
}
\details{
When called with its default arguments, the following will happen:
\itemize{
\item Double periods (\code{..}) will be replaced with single periods (\code{.})
\item Four or more periods (\code{...} or \code{.....}) will be replaced with three periods
\item Three or more newline characters will be replaced by one newline character (which
will become more, if the sentence before that character marks the end of an
utterance)
\item All sentences will become separate utterances (in a semi-smart manner;
specifically, breaks in speaking, if represented by three periods, are not
considered sentence ends, wheread ellipses ("…" or unicode 2026, see the example) \emph{are}.
\item If there are comma's without a space following them, a space will be inserted.
}
}
\examples{
exampleSource <-
"Do you like icecream?


Well, that depends\\u2026 Sometimes, when it's..... Nice. Then I do,
but otherwise... not really, actually."

### Default settings:
cat(clean_source(exampleSource));

### First remove existing newlines:
cat(clean_source(exampleSource,
                 removeNewlines=TRUE));

}
