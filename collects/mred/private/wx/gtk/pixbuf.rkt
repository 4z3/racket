#lang racket
(require racket/class
         ffi/unsafe
         racket/draw
         "../../lock.rkt"
         "../common/bstr.rkt"
         "utils.rkt"
         "types.rkt"
         (only-in '#%foreign ffi-callback))

(provide _GdkPixbuf
         bitmap->pixbuf
         gtk_image_new_from_pixbuf)

(define _GdkPixbuf (_cpointer 'GdkPixbuf))

(define-gtk gtk_image_new_from_pixbuf (_fun _GdkPixbuf -> _GtkWidget))
(define-gdk_pixbuf gdk_pixbuf_new_from_data (_fun _pointer ; data
						  _int ; 0  =RGB
						  _gboolean ; has_alpha?
						  _int ; bits_per_sample
						  _int ; width
						  _int ; height
						  _int ; rowstride
						  _fpointer ; destroy
						  _pointer  ; destroy data
						  -> _GdkPixbuf))
(define free-it (ffi-callback free
                              (list _pointer)
                              _void
                              #f
                              #t))

(define (bitmap->pixbuf bm)
  (let* ([w (send bm get-width)]
         [h (send bm get-height)]
         [str (make-bytes (* w h 4) 255)])
    (send bm get-argb-pixels 0 0 w h str #f)
    (when (send bm get-loaded-mask)
      (send bm get-argb-pixels 0 0 w h str #t))
    (as-entry
     (lambda ()
       (let ([rgba (scheme_make_sized_byte_string (malloc (* w h 4) 'raw) (* w h 4) 0)])
         (memcpy rgba (ptr-add str 1) (sub1 (* w h 4)))
         (for ([i (in-range 0 (* w h 4) 4)])
           (bytes-set! rgba (+ i 3) (bytes-ref str i)))
         (gdk_pixbuf_new_from_data rgba
                                   0
                                   #t
                                   8
                                   w
                                   h
                                   (* w 4)
                                   free-it
                                   #f))))))