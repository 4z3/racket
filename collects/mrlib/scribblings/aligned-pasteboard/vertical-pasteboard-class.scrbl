#lang scribble/doc
@(require "common.ss")

@defclass/title[vertical-pasteboard% pasteboard% (aligned-pasteboard<%>)]{

@defconstructor/auto-super[()]{
Passes all arguments to @scheme[super-init].
}

@defmethod[#:mode override 
           (after-delete [snip (is-a?/c snip%)])
           void?]{}

@defmethod[#:mode override 
           (after-insert [snip (is-a?/c snip%)]
                         [before (or/c (is-a?/c snip%) false/c)]
                         [x real?]
                         [y real?])
           void?]{}

@defmethod[#:mode override 
           (after-reorder [snip (is-a?/c snip%)]
                          [to-snip (is-a?/c snip%)]
                          [before? any/c])
           boolean?]{}

@defmethod[#:mode override 
           (resized [snip (is-a?/c snip%)]
                    [redraw-now? any/c])
           void?]{}}
