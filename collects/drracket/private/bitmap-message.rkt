#lang racket/base

(require racket/gui/base racket/class)
(provide bitmap-message%)

(define bitmap-message%
  (class canvas%
    (inherit min-width min-height get-dc refresh)
    (define bm #f)
    (define/override (on-paint)
      (when bm
        (let ([dc (get-dc)])
          (send dc draw-bitmap bm 0 0))))
    (define/public (set-bm b)
      (set! bm b)
      (min-width (send bm get-width))
      (min-height (send bm get-height))
      (refresh))
    (super-new (stretchable-width #f)
               (stretchable-height #f))))
