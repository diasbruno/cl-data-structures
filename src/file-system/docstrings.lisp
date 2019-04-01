(in-package #:cl-data-structures.file-system)


(docs:define-docs
  :formatter docs.ext:rich-aggregating-formatter

  (function line-by-line
    (:description "Opens a text file, and allows reading it line by line."
     :returns "Forward range. Provides access to each line in the file stored as string."
     :exceptional-situations ("Signalling error from callback during traverse will close the inner stream."
                              "Signals errors just as CL:OPEN does.")
     :notes "File is opened lazily. Calling either TRAVERSE or ACROSS on the line-by-line range will automaticly close the inner file. This makes it suitable to use with the aggregation functions without additional code."))

  (function find
    (:description "Function that is somewhat similar to posix find tool. Depending on the current filesystem and the DESCRIPTION list, it will return forward-range containing pathnames matching DESCRIPTION.")))
