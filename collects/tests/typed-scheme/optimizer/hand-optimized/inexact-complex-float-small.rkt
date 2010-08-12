#lang typed/scheme #:optimize
(require racket/unsafe/ops)
(let* ((unboxed-real-1 1.0)
       (unboxed-imag-2 2.0)
       (unboxed-float-3 3.0)
       (unboxed-real-4 (unsafe-fl+ unboxed-real-1 unboxed-float-3))
       (unboxed-imag-5 unboxed-imag-2))
  (unsafe-make-flrectangular unboxed-real-4 unboxed-imag-5))
(let* ((unboxed-float-1 1.0)
       (unboxed-real-2 2.0)
       (unboxed-imag-3 4.0)
       (unboxed-real-4 (unsafe-fl+ unboxed-float-1 unboxed-real-2))
       (unboxed-imag-5 unboxed-imag-3))
  (unsafe-make-flrectangular unboxed-real-4 unboxed-imag-5))
(let* ((unboxed-real-1 1.0)
       (unboxed-imag-2 2.0)
       (unboxed-float-3 3.0)
       (unboxed-real-4 (unsafe-fl- unboxed-real-1 unboxed-float-3))
       (unboxed-imag-5 unboxed-imag-2))
  (unsafe-make-flrectangular unboxed-real-4 unboxed-imag-5))
(let* ((unboxed-float-1 1.0)
       (unboxed-real-2 2.0)
       (unboxed-imag-3 4.0)
       (unboxed-real-4 (unsafe-fl- unboxed-float-1 unboxed-real-2))
       (unboxed-imag-5 (unsafe-fl- 0.0 unboxed-imag-3)))
  (unsafe-make-flrectangular unboxed-real-4 unboxed-imag-5))
(let* ((unboxed-real-1 1.0)
       (unboxed-imag-2 2.0)
       (unboxed-float-3 (unsafe-fl+ 1.0 2.0))
       (unboxed-real-4 (unsafe-fl+ unboxed-real-1 unboxed-float-3))
       (unboxed-imag-5 unboxed-imag-2))
  (unsafe-make-flrectangular unboxed-real-4 unboxed-imag-5))