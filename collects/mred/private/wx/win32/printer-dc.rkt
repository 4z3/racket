#lang racket/base
(require racket/class
         ffi/unsafe
         ffi/unsafe/alloc
         racket/draw/private/dc
         racket/draw/private/local
         racket/draw/unsafe/cairo
         racket/draw/private/record-dc
         racket/draw/private/bitmap-dc
         racket/draw/private/ps-setup
         "../../lock.rkt"
         "dc.rkt"
         "types.rkt"
         "utils.rkt"
         "const.rkt")

(provide
 (protect-out printer-dc%
              show-print-setup))

(define _HGLOBAL _pointer)

(define-cstruct _PAGESETUPDLG
  ([lStructSize _DWORD]
   [hwndOwner _HWND]
   [hDevMode _HGLOBAL]
   [hDevNames _HGLOBAL]
   [Flags _DWORD]
   [ptPaperSize _POINT]
   [rtMinMargin _RECT]
   [rtMargin _RECT]
   [hInstance _HINSTANCE]
   [lCustData _LPARAM]
   [lpfnPageSetupHook _fpointer]
   [lpfnPagePaintHook _fpointer]
   [lpPageSetupTemplateName _pointer]
   [hPageSetupTemplate _HGLOBAL]))

(define-cstruct _PRINTDLG
  ([lStructSize _DWORD]
   [hwndOwner _HWND]
   [hDevMode _HGLOBAL]
   [hDevNames _HGLOBAL]
   [hDC _HDC]
   [Flags _DWORD]
   [nFromPage _WORD]
   [nToPage _WORD]
   [nMinPage _WORD]
   [nMaxPage _WORD]
   [nCopies _WORD]
   [hInstance _HINSTANCE]
   [lCustData _LPARAM]
   [lpfnPrintHook _fpointer]
   [lpfnSetupHook _fpointer]
   [lpPrintTemplateName _pointer]
   [lpSetupTemplateName _pointer]
   [hPrintTemplate _HGLOBAL]
   [hSetupTemplate _HGLOBAL])
  #:alignment 2)

(define-cstruct _DOCINFO
  ([cbSize _int]
   [lpszDocName _permanent-string/utf-16]
   [lpszOutput _pointer]
   [lpszDatatype _pointer]
   [fwType _DWORD]))

(define PD_RETURNDC #x00000100)

(define PSD_INTHOUSANDTHSOFINCHES         #x00000004)
(define PSD_INHUNDREDTHSOFMILLIMETERS     #x00000008)

(define-comdlg32 PageSetupDlgW (_wfun _PAGESETUPDLG-pointer -> _BOOL))
(define-comdlg32 PrintDlgW (_wfun _PRINTDLG-pointer -> _BOOL))

(define-gdi32 StartDocW (_wfun _HDC _DOCINFO-pointer -> _int))
(define-gdi32 StartPage (_wfun _HDC -> (r : _int) -> (unless (positive? r) (failed 'StartPage))))
(define-gdi32 EndPage (_wfun _HDC -> (r : _int) -> (unless (positive? r) (failed 'EndPage))))
(define-gdi32 EndDoc (_wfun _HDC -> (r : _int) -> (unless (positive? r) (failed 'EndDoc))))

(define needs-delete ((allocator DeleteDC) values))

(define (clone-page-setup p)
  (let ([new-p (malloc 1 _PAGESETUPDLG)])
    (set-cpointer-tag! new-p PAGESETUPDLG-tag)
    (memcpy new-p 0 p 1 _PAGESETUPDLG)
    new-p))

(define PSD_RETURNDEFAULT #x00000400)

(define (show-print-setup parent [just-create? #f])
  (let* ([pss (current-ps-setup)]
         [ps (send pss get-native)])
    (atomically
     (let ([p (malloc 'raw 1 _PAGESETUPDLG)])
       (set-cpointer-tag! p PAGESETUPDLG-tag)
       (if ps
           (memcpy p 0 ps 1 _PAGESETUPDLG)
           (begin
             (memset p 0 1 _PAGESETUPDLG)
             (set-PAGESETUPDLG-lStructSize! p (ctype-sizeof _PAGESETUPDLG))))
       (set-PAGESETUPDLG-Flags! p (if just-create?
                                      PSD_RETURNDEFAULT
                                      0))
       (let ([r (PageSetupDlgW p)])
         (when r
           (let ([new-p (clone-page-setup p)])
             (send pss set-native new-p values)))
         (free p)
         ;; FIXME: `r' leaks handles through
         ;; the hDevModes and hDevNames fields
         r)))))

(define printer-dc%
  (class (record-dc-mixin (dc-mixin bitmap-dc-backend%))
    (init [parent #f])

    (super-make-object (make-object win32-bitmap% 1 1 #f))

    (inherit get-recorded-command
             reset-recording)

    (define pages null)
    (define/override (end-page)
      (set! pages (cons (get-recorded-command) pages))
      (reset-recording))

    (define page-setup (or (send (current-ps-setup) get-native)
                           (begin
                             (show-print-setup #f #t)
                             (send (current-ps-setup) get-native))))
    
    (define-values (page-width page-height)
      (let ([scale (if (zero? (bitwise-and (PAGESETUPDLG-Flags page-setup)
                                           PSD_INTHOUSANDTHSOFINCHES))
                       ;; 100ths of mm
                       (/ 72.0 (/ 10.0 2.54))
                       ;; 1000ths of in
                       (/ 72.0 1000.0))])
      (values
       (* scale (POINT-x (PAGESETUPDLG-ptPaperSize page-setup)))
       (* scale (POINT-y (PAGESETUPDLG-ptPaperSize page-setup))))))



    (define/override (get-size) (values page-width page-height))

    (define start-doc-message #f)
    (define/override (start-doc s)
      (super start-doc s)
      (set! start-doc-message (and s (string->immutable-string s))))
    
    (define/override (end-doc)
      (let-values ([(hdc from-page to-page)
                    (atomically
                     (let ([p (malloc 'raw 1 _PRINTDLG)])
                       (set-cpointer-tag! p PRINTDLG-tag)
                       (memset p 0 1 _PRINTDLG)
                       (set-PRINTDLG-lStructSize! p (ctype-sizeof _PRINTDLG))
                       (set-PRINTDLG-hDevMode! p (PAGESETUPDLG-hDevMode page-setup))
                       (set-PRINTDLG-hDevNames! p (PAGESETUPDLG-hDevNames page-setup))
                       (set-PRINTDLG-Flags! p (bitwise-ior PD_RETURNDC))
                       (set-PRINTDLG-nFromPage! p 1)
                       (set-PRINTDLG-nToPage! p (length pages))
                       (set-PRINTDLG-nMinPage! p 1)
                       (set-PRINTDLG-nMaxPage! p (length pages))
                       (set-PRINTDLG-nCopies! p 1)
                       (let ([r (PrintDlgW p)])
                         (begin0
                          (if r 
                              (values (needs-delete (PRINTDLG-hDC p))
                                      (PRINTDLG-nFromPage p)
                                      (PRINTDLG-nToPage p))
                              (values #f #f #f))
                          (free p)))))])
        (when hdc
          (atomically
           (let ([job
                  (let ([di (make-DOCINFO (ctype-sizeof _DOCINFO)
                                          start-doc-message
                                          #f
                                          #f
                                          0)])
                    (begin0
                     (StartDocW hdc di)
                     (when start-doc-message
                       (free (DOCINFO-lpszDocName di)))))])
             (when (positive? job)
               (for ([proc (in-list (reverse pages))]
                     [page-no (in-naturals 1)])
                 (when (<= from-page page-no to-page)
                   (StartPage hdc)
                   (let* ([s (cairo_win32_surface_create hdc)]
                          [cr (cairo_create s)])
                     (set-point-scale hdc cr)
                     (proc
                      (make-object
                       (class (dc-mixin default-dc-backend%)
                         (super-new)
                         (define/override (init-cr-matrix cr)
                           (set-point-scale hdc cr))
                         (define/override (get-cr) cr))))
                     (cairo_destroy cr)
                     (cairo_surface_destroy s))
                   (EndPage hdc)))
               (EndDoc hdc))
             (DeleteDC hdc))))))))

(define-gdi32 GetDeviceCaps (_wfun _HDC _int -> _int))

(define LOGPIXELSX    88)
(define LOGPIXELSY    90)

(define (set-point-scale hdc cr)
  (let* ([lpx (GetDeviceCaps hdc LOGPIXELSX)]
         [lpy (GetDeviceCaps hdc LOGPIXELSY)]
         [lx (/ (if (zero? lpx) 300 lpx) 72.0)]
         [ly (/ (if (zero? lpy) 300 lpy) 72.0)])
    (cairo_scale cr lx ly)))
