#' @export
parse_source <- function(x,
                         codeRegexes = c(code = "\\[\\[([a-zA-Z0-9._>-]+)\\]\\]"),
                         idRegexes = c(caseId = "\\[\\[cid=([a-zA-Z0-9._-]+)\\]\\]",
                                       stanzaId = "\\[\\[sid=([a-zA-Z0-9._-]+)\\]\\]"),
                         autoGenerateIds = c('stanzaId'),
                         persistentIds = c('caseId'),
                         sectionRegexes = c(paragraphs = "---paragraph-break---",
                                            secondary = "---<[a-zA-Z0-9]?>---"),
                         inductiveCodingHierarchyMarker = ">",
                         delimiterRegEx = "^---$",
                         ignoreRegex = "^#",
                         ignoreOddDelimiters=FALSE,
                         silent=FALSE) {

  arguments <- as.list(environment());

  ### First remove lines to ignore
  linesToIgnore <- grepl(ignoreRegex,
                         x);
  ignoredLines <- x[linesToIgnore];
  x <- x[!linesToIgnore];

  ### First process YAML fragments and remove them
  yamlFragments <-
    extract_yaml_fragments(text=x,
                           delimiterRegEx=delimiterRegEx,
                           ignoreOddDelimiters=ignoreOddDelimiters);
  x <-
    delete_yaml_fragments(text=x,
                          delimiterRegEx=delimiterRegEx,
                          ignoreOddDelimiters=ignoreOddDelimiters);

  ### Create dataframe for parsing
  sourceDf <- data.frame(utterances_raw = x,
                         stringsAsFactors=FALSE);

  ### Identify sections
  if (!is.null(sectionRegexes) && length(sectionRegexes) > 0) {
    for (sectionRegex in names(sectionRegexes)) {
      ### Store whether each utterance matches
      sourceDf[, glue::glue("{sectionRegex}_match")] <-
        grepl(sectionRegexes[sectionRegex], x);
      ### Set incremental counter for each match
      sourceDf[, glue::glue("{sectionRegex}_counter")] <-
        purrr::accumulate(sourceDf[, glue::glue("{sectionRegex}_match")],
                          `+`);
    }
  }

  ### Process identifiers
  if (!is.null(idRegexes) && length(idRegexes) > 0) {
    for (idRegex in names(idRegexes)) {

      ### Get a list of matches
      ids <-
        regmatches(x,
                   gregexpr(idRegexes[idRegex], x));

      ### Check whether there are multiple matches
      multipleIds <-
        which(unlist(lapply(ids, length))>1);
      if (length(multipleIds) > 0) {
        warning(glue::glue("Multiple identifiers matching '{idRegex}' found in the following utterances:\n",
                       paste0(x[multipleSids],
                              collapse="\n"),
                       "\n\nOnly using the first identifier for each utterance, removing and ignoring the rest!"));
        ids <-
          lapply(ids, head, 1);
      }

      ### Clean identifiers (i.e. only retain identifier content itself)
      ids <-
        lapply(ids, gsub, pattern=idRegexes[idRegex], replacement="\\1");

      ### Set "no_id" for utterances without id
      ids <-
        ifelse(unlist(lapply(ids,
                             length)),
               ids,
               "no_id");

      ### Convert from a list to a vector
      ids <- unlist(ids);

      if (length(ids) > 0) {
        ### Implement 'identifier persistence' by copying the
        ### identifier of the previous utterance if the identifier
        ### is not set - can't be done using vectorization as identifiers
        ### have to carry over sequentially.
        if (idRegex %in% persistentIds) {
          rawIds <- ids;
          for (i in 2:length(ids)) {
            if ((ids[i] == "no_id")) {
              ids[i] <- ids[i-1];
            }
          }
        }
      } else {
        ids = "no_id";
      }

      ### Check whether any matches were found
      if (!(all(ids=="no_id"))) {
        ### Generate identifiers for ids without identifier
        if (idRegex %in% autoGenerateIds) {
          ids[ids=="no_id"] <-
            paste0("autogenerated_id_",
                   1:(sum(ids=="no_id")));
        }
        ### Store identifiers in sourceDf
        sourceDf[, idRegex] <-
          ids;
        if (idRegex %in% persistentIds) {
          sourceDf[, paste0(idRegex, "_raw")] <-
            rawIds;
        }
      }
    }
  }

  ### Delete identifiers and store clean version in sourceDf
  x <-
    gsub(paste0(idRegexes, collapse="|"),
         "",
         x);
  sourceDf$utterances_without_identifiers <- x;

  codings <- list();
  codingLeaves <- list();
  inductiveCodeProcessing <- list();
  inductiveCodeTrees <- list();
  ### Process codes
  if (!is.null(codeRegexes) && length(codeRegexes) > 0) {

    for (codeRegex in names(codeRegexes)) {

      ### Find matches
      matches <-
        regmatches(x,
                   gregexpr(codeRegexes[codeRegex], x));

      ### Retain only the parenthesized expression
      cleanedMatches <-
        lapply(matches, gsub, pattern=codeRegexes[codeRegex], replacement="\\1");

      ### Get a complete list of all used codes
      codings[[codeRegex]] <-
        sort(unique(unlist(cleanedMatches)));

      ### Split these unique codes into levels
      if ((nchar(inductiveCodingHierarchyMarker) > 0) &&
          (!is.null(codings[[codeRegex]])) &&
          (length(codings[[codeRegex]]) > 0)) {
        inductiveCodeProcessing[[codeRegex]] <- list();

        inductiveCodeProcessing[[codeRegex]]$splitCodings <-
          strsplit(codings[[codeRegex]],
                   inductiveCodingHierarchyMarker);

        inductiveCodeProcessing[[codeRegex]]$inductiveLeaves <-
          unlist(lapply(inductiveCodeProcessing[[codeRegex]]$splitCodings,
                        tail,
                        1));
      } else {
        inductiveCodeProcessing[[codeRegex]]$inductiveLeaves <-
          codings[[codeRegex]];
      }

      codingLeaves[[codeRegex]] <-
        inductiveCodeProcessing[[codeRegex]]$inductiveLeaves;

      ### Get presence of codes in utterances
      occurrences <-
        lapply(cleanedMatches,
               `%in%`,
               x=codings[[codeRegex]]);

      ### Convert from logical to numeric
      occurrenceCounts <-
        lapply(occurrences, as.numeric);

      ### Add the codes as names
      namedOccurrences <-
        lapply(occurrenceCounts,
               `names<-`,
               value <- inductiveCodeProcessing[[codeRegex]]$inductiveLeaves);

      ### Convert from a vector to a list
      namedOccurrences <-
        lapply(namedOccurrences,
               as.list);

      ### Convert the lists to dataframes
      sourceDf <-
        cbind(sourceDf,
              do.call(rbind, namedOccurrences));

      ### Delete codes from utterances
      x <-
        gsub(codeRegexes[codeRegex],
             "",
             x);

      if ((nchar(inductiveCodingHierarchyMarker) > 0) &&
          (!is.null(inductiveCodeProcessing[[codeRegex]]$inductiveLeaves)) &&
          (length(inductiveCodeProcessing[[codeRegex]]$inductiveLeaves) > 0)) {

        ### Build tree for this code regex. First some preparation.
        inductiveCodeProcessing[[codeRegex]]$localRoots <-
          unlist(lapply(inductiveCodeProcessing[[codeRegex]]$splitCodings,
                        head, 1));
        inductiveCodeProcessing[[codeRegex]]$localBranches <-
          unlist(lapply(inductiveCodeProcessing[[codeRegex]]$splitCodings,
                        tail, -1));
        inductiveCodeProcessing[[codeRegex]]$localRootsThatAreBranches <-
          unlist(lapply(inductiveCodeProcessing[[codeRegex]]$localRoots,
                        `%in%`,
                        inductiveCodeProcessing[[codeRegex]]$localBranches));

        ### Convert split codings into node-ready lists
        inductiveCodeProcessing[[codeRegex]]$subTrees <-
          lapply(inductiveCodeProcessing[[codeRegex]]$splitCodings,
                 function(subTree) {
                   return(lapply(subTree,
                                 function(x) {
                                   setNames(list(x,x,x),
                                            c(idName,
                                              labelName,
                                              codeName));
                                 }));

                 });

        ### Local roots that are not branches should be attached to the root of
        ### the inductive code tree for this code set, along with their children.
        inductiveCodeTrees[[codeRegex]] <-
          data.tree::Node$new('codes');

        ### First add only the local roots that have no parents
        for (currentLocalRoot in unique(inductiveCodeProcessing[[codeRegex]]$localRoots[
                                          !inductiveCodeProcessing[[codeRegex]]$localRootsThatAreBranches
                                        ])) {
          ### Add first node to the root
          inductiveCodeTrees[[codeRegex]]$AddChild(currentLocalRoot);
          inductiveCodeTrees[[codeRegex]][[currentLocalRoot]]$label <-
            currentLocalRoot;
          inductiveCodeTrees[[codeRegex]][[currentLocalRoot]]$code <-
            currentLocalRoot;
        }

        ### Then process their branches/children
        for (currentSubtree in inductiveCodeProcessing[[codeRegex]]$splitCodings[
                                 !inductiveCodeProcessing[[codeRegex]]$localRootsThatAreBranches
                               ]) {
          if (length(currentSubtree) > 1) {
            ### Add children; first save reference to this node
            currentNode <-
              inductiveCodeTrees[[codeRegex]][[currentSubtree[1]]];
            ### Then loop through children and progressively add them
            for (currentBranch in currentSubtree[2:length(currentSubtree)]) {
              currentNode <-
                currentNode$AddChild(currentBranch);
              currentNode$label <-
                currentBranch;
              currentNode$code <-
                currentBranch;
            }
          }
        }

        ### Then start working on the subtrees that should be attached to
        ### a parent
        for (i in seq_along(inductiveCodeProcessing[[codeRegex]]$splitCodings[
                                 inductiveCodeProcessing[[codeRegex]]$localRootsThatAreBranches
                               ])) {
          currentSubtree <-
            inductiveCodeProcessing[[codeRegex]]$splitCodings[
              inductiveCodeProcessing[[codeRegex]]$localRootsThatAreBranches
            ][[i]];
          currentNode <-
            data.tree::FindNode(inductiveCodeTrees[[codeRegex]],
                                currentSubtree[1]);
          if (is.null(currentNode)) {
            warning(paste0("Code '", codings[[codeRegex]][i], "' does not ",
                           "have a parent I can find!"));
          } else {
            ### If it's found, loop through the children and progressively add them
            for (currentBranch in currentSubtree[2:length(currentSubtree)]) {
              currentNode <-
                currentNode$AddChild(currentBranch);
              currentNode$label <-
                currentBranch;
              currentNode$code <-
                currentBranch;
            }
          }
        }

        SetGraphStyle(inductiveCodeProcessing[[codeRegex]],
                      directed="false");

      } else {
        inductiveCodeTrees[[codeRegex]] <- NULL;
      }

    }
  }

  ### Trim spaces from front and back and store clean utterances
  sourceDf$utterances_clean <-
    trimws(x);

  if (nrow(sourceDf) > 0) {
    sourceDf$originalSequenceNr <- 1:nrow(sourceDf);

    cleanSourceDf <-
      sourceDf[!grepl(paste0(sectionRegexes, collapse="|"),
                      x), ];

    cleanSourceDf <-
      cleanSourceDf[nchar(cleanSourceDf$utterances_clean)>0, ];
  } else {
    cleanSourceDf <- data.frame();
  }

  if (nrow(cleanSourceDf) > 0) {
    cleanSourceDf$sequenceNr <- 1:nrow(cleanSourceDf);
  }

  return(structure(list(arguments = arguments,
                        sourceDf = cleanSourceDf,
                        rawSourceDf = sourceDf,
                        codings = codingLeaves,
                        rawCodings = codings,
                        inductiveCodeProcessing = inductiveCodeProcessing,
                        inductiveCodeTrees = inductiveCodeTrees,
                        yamlFragments = yamlFragments),
                   class="rockParsedSource"));

}

#' @rdname parse_source
#' @method print rockParsedSource
#' @export
print.rockParsedSource <- function(x, prefix="### ",  ...) {
  totalSectionMatches <-
    sum(unlist(lapply(x$rawSourceDf[, grep('_match',
                                           names(x$rawSourceDf))],
                      as.numeric)));

  appliedCodes <-
    sort(unique(unlist(x$codings)));

  totalCodingMatches <-
    sum(unlist(x$sourceDf[, appliedCodes]));

  if (length(x$inductiveCodeTrees) > 0) {
    inductiveTreesInfo <-
      glue::glue("This source contained inductive coding trees. ",
                 "These are shown in R Studio's viewer.\n\n")
  } else {
    inductiveTreesInfo <-
      glue::glue("This source contained no inductive coding trees.\n\n")
  }

  identifiers <-
    names(x$arguments$idRegexes);
  occurringIdentifiers <-
    identifiers[identifiers %in% names(x$sourceDf)];

  if (length(occurringIdentifiers) > 0) {
    actualIdentifiers <-
      lapply(x$sourceDf[, occurringIdentifiers, drop=FALSE],
             unique);
    actualIdentifiers <-
      lapply(actualIdentifiers,
             sort);
    actualIdentifiers <-
      lapply(actualIdentifiers,
             function(x) return(x[!(x=="no_id")]));
    identifierInfo <-
      glue::glue("This source contained matches with identifier regular expressions. Specifically, ",
                 glue::glue_collapse(lapply(names(actualIdentifiers),
                                            function(x) return(glue::glue("identifier regular expression '{x}' matched ",
                                                                          "with identifiers {ufs::vecTxtQ(actualIdentifiers[[x]])}"))),
                                     ", "),
                 ".");
  } else {
    identifierInfo <-
      glue::glue("This source contained no matches with identifier regular expressions.")
  }

  print(glue::glue("\n\n",
                   "{prefix}Preprocessing\n\n",
                   "The parsed source contained {length(x$arguments$x)} lines. ",
                   "After removing lines that matched '{x$arguments$ignoreRegex}', ",
                   "the regular expression specifying which lines to ignore, and did not ",
                   "make up the {length(x$yamlFragments)} YAML fragments with metadata or ",
                   "deductive coding tree specifications, {nrow(x$rawSourceDf)} lines remained.",
                   " {totalSectionMatches} of these matched one of the section regular ",
                   "expressions ({ufs::vecTxtQ(x$arguments$sectionRegexes)}), and after ",
                   " removing these lines and all lines that were empty after removing ",
                   " characters that matched one or more identifier ",
                   "({ufs::vecTxtQ(x$arguments$idRegexes)}) and coding ",
                   "({ufs::vecTxtQ(x$arguments$codeRegexes)}) regular expressions, ",
                   "{nrow(x$sourceDf)} utterances remained.",
                   "\n\n",
                   "{prefix}Identifiers\n\n",
                   identifierInfo,
                   "\n\n",
                   "{prefix}Utterances and coding\n\n",
                   "These {nrow(x$sourceDf)} utterances were coded ",
                   "{totalCodingMatches} times in total using these codes: ",
                   "{ufs::vecTxtQ(appliedCodes)}.",
                   "\n\n",
                   "{prefix}Inductive coding trees\n\n",
                   inductiveTreesInfo));
  for (i in x$inductiveCodeTrees) {
    print(plot(i));
  }
  invisible(x);
}

# x <- readLines("B:/Data/research/qualitative-quantitative interfacing/Qualitative rENA/arena/sylvias-test.rock",
#                encoding="UTF-8");
#
# y <- parse_source(x);