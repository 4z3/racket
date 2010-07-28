#lang scheme/base
(require scheme/class
         scheme/foreign
         ffi/objc
          "../../syntax.rkt"
         "item.rkt"
         "types.rkt"
         "const.rkt"
         "utils.rkt"
         "window.rkt")
(unsafe!)
(objc-unsafe!)

(provide gauge%)

;; ----------------------------------------

(import-class NSProgressIndicator)

(define-objc-class MyProgressIndicator NSProgressIndicator
  #:mixins ()
  [wx])

(defclass gauge% item%
  (init parent
        label
        rng
        x y w h
        style
        font)
  (inherit get-cocoa)

  (super-new [parent parent]
             [cocoa (let ([cocoa (tell (tell MyProgressIndicator alloc) init)])
                      (tellv cocoa setIndeterminate: #:type _BOOL #f)
                      (tellv cocoa setMaxValue: #:type _double* rng)
                      (tellv cocoa setDoubleValue: #:type _double* 0.0)
                      #;
                      (tellv cocoa setFrame: #:type _NSRect (make-NSRect 
                                                             (make-NSPoint 0 0)
                                                             (make-NSSize (if vert? 24 32)
                                                                          (if vert? 32 24))))
                      (tellv cocoa sizeToFit)
                      cocoa)]
             [callback void]
             [no-show? (memq 'deleted style)])
  
  (define cocoa (get-cocoa))

  (define/override (enable on?) (void))
  (define/override (is-window-enabled?) #t)

  (define/public (get-range)
    (inexact->exact (floor (tell #:type _double cocoa maxValue))))
  (define/public (set-range rng)
    (tellv cocoa setMaxValue: #:type _double* rng))

  (define/public (set-value v)
    (tellv cocoa setDoubleValue: #:type _double* v))
  (define/public (get-value)
    (min (inexact->exact (floor (tell #:type _double cocoa doubleValue)))
         (get-range))))