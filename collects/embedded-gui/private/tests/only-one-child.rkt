(require
 mred
 mzlib/class
 mzlib/etc
 mzlib/list
 mzlib/match
 (prefix a: "../alignment.ss")
 "../alignment-helpers.ss"
 "../dllist.ss"
 mrlib/click-forwarding-editor
 "../on-show-pasteboard.ss"
 "../really-resized-pasteboard.ss"
 "../interface.ss"
 "../locked-pasteboard.ss"
 "../suppress-modify-editor.ss")

;;;;;;;;;;
;; alignment

(define (vert/horiz-alignment type)
  (class* dllist% ()
    
    (init-field [parent #f])
    
    (field
     [head (new head%)]
     [tail (new tail%)])
    
    (send head next tail)
    (send tail prev head)
    
    #;(((is-a?/c alignment<%>)) ((union (is-a?/c alignment<%>) false?)) . opt-> . void?)
    ;; Add the given alignment as a child before the existing child
    (define/public add-child
      (opt-lambda (child (after #f))
        (define (link p item n)
          (send p next child)
          (send child prev p)
          (send n prev child)
          (send child next n))
        (if after
            (link after child (send after next))
            (link (send tail prev) child tail))))
    
    (super-new)
    (when parent (send parent add-child this))))

(define vertical-alignment% (vert/horiz-alignment 'vertical))
(define horizontal-alignment% (vert/horiz-alignment 'horizontal))

(let* ([interactions (new vertical-alignment% (parent (new vertical-alignment%)))])
  (new horizontal-alignment% (parent interactions))
  (new horizontal-alignment% (parent interactions))
  `(equal? ,(length (send interactions map-to-list (lambda (x) x))) 2))
