#lang scribble/doc
@(require "common.ss")

@defclass/title[pdf-dc% object% (dc<%>)]{

Like @racket[post-script-dc%], but generates a PDF file instead of a
 PostScript file.

@defconstructor[([interactive any/c #t]
                 [parent (or/c (is-a?/c frame%) (is-a?/c dialog%) false/c) #f]
                 [use-paper-bbox any/c #f]
                 [as-eps any/c #t])]{

See @racket[post-script-dc%] for information on the arguments. The
@racket[as-eps] argument is allowed for consistency with
@racket[post-script-dc%], but its value is ignored.}}

