#lang racket/base
(require ffi/unsafe
	 racket/class
         "../../lock.rkt"
	 "utils.rkt"
	 "types.rkt"
	 "const.rkt"
	 "icons.rkt")

(provide hInstance
	 DefWindowProcW
         background-hbrush
	 set-hwnd-wx!
	 set-hwnd-ctlproc!
         hwnd->wx
         hwnd->ctlproc
	 any-hwnd->wx
	 unregister-hwnd
	 MessageBoxW
         _WndProc)

;; ----------------------------------------
;; We use the "user data" field of an HWND to
;;  store a weak pointer back to the Racket object.
;;  The weak pointer must be wrapped in an immuable cell.
;;  In addition, if we need to save a control's old
;;  ctlproc, we put it in the same immutable cell.
;; So:
;;  <user-data>   = (make-immutable-cell <remembered>)
;;  <remembered>  = <wx-weak-box>
;;                | (cons <ctlproc> <wx-weak-box>)
;;  <wx-weak-box> = (make-weak-box <object%>)

(define all-cells (make-hash))

(define (set-hwnd-wx! hwnd wx)
  (let ([c (malloc-immobile-cell (make-weak-box wx))])
    (SetWindowLongW hwnd GWLP_USERDATA c)
    (atomically (hash-set! all-cells (cast c _pointer _long) #t))))

(define (set-hwnd-ctlproc! hwnd ctlproc)
  (let ([p (GetWindowLongW hwnd GWLP_USERDATA)])
    (ptr-set! p _racket (cons (ptr-ref p _racket) ctlproc))))

(define (hwnd->wx hwnd)
  (let ([p (GetWindowLongW hwnd GWLP_USERDATA)])
    (and p (let ([wb (ptr-ref p _racket)])
             (and wb
                  (weak-box-value (if (pair? wb) 
                                      (car wb) 
                                      wb)))))))

(define (hwnd->ctlproc hwnd)
  (let ([p (GetWindowLongW hwnd GWLP_USERDATA)])
    (and p (let ([wb (ptr-ref p _racket)])
             (and wb
                  (pair? wb)
                  (cdr wb))))))

(define (any-hwnd->wx hwnd)
  (let ([p (GetWindowLongW hwnd GWLP_USERDATA)])
    (and p 
         (atomically (hash-ref all-cells (cast p _pointer _long) #f))
         (let ([wx (let ([wb (ptr-ref p _racket)])
                     (and wb 
                          (weak-box-value (if (pair? wb)
                                              (car wb)
                                              wb))))])
           (and wx
                (send wx is-hwnd? hwnd)
                wx)))))

(define (unregister-hwnd hwnd)
  (let ([p (GetWindowLongW hwnd GWLP_USERDATA)])
    (when p
      (free-immobile-cell p)
      (SetWindowLongW hwnd GWLP_USERDATA #f))))

;; ----------------------------------------

(define-cstruct _INITCOMMONCONTROLSEX
  ([dwSize _DWORD]
   [dwICC _DWORD]))

(define-comctl32 InitCommonControlsEx (_wfun _INITCOMMONCONTROLSEX-pointer -> _BOOL))

(void
 (InitCommonControlsEx (make-INITCOMMONCONTROLSEX
			(ctype-sizeof _INITCOMMONCONTROLSEX)
			0)))

;; ----------------------------------------

(define _WndProc (_wfun #:atomic? #t #:keep (box null)
			_HWND _UINT _WPARAM _LPARAM -> _LRESULT))

(define-cstruct _WNDCLASS ([style _UINT]
			   [lpfnWndProc _fpointer]
			   [cbClsExtra _int]
			   [cbWndExtra _int]
			   [hInstace _HINSTANCE]
			   [hIcon _HICON]
			   [hCursor _HCURSOR]
			   [hbrBackground _HBRUSH]
			   [lpszMenuName _permanent-string/utf-16]
			   [lpszClassName _permanent-string/utf-16]))

(define-user32 RegisterClassW (_wfun _WNDCLASS-pointer -> _ATOM))
(define-kernel32 GetModuleHandleW (_wfun _pointer -> _HINSTANCE))
(define-user32 LoadCursorW (_wfun _HINSTANCE _pointer -> _HCURSOR))
(define-user32 LoadIconW (_wfun _HINSTANCE _string/utf-16 -> _HICON))

(define-user32 GetClassInfoW (_wfun _HINSTANCE _string/utf-16 (i : (_ptr o _WNDCLASS)) -> (r : _BOOL)
                                    -> (if r i (failed 'GetClassInfoW))))

(define-user32 DefWindowProcW (_wfun _HWND _UINT _WPARAM _LPARAM -> _LRESULT))
(define-user32 DefWindowProcW/raw _fpointer
  #:c-id DefWindowProcW)

#;(define-user32 PostQuitMessage (_wfun _int -> _void))

(define (wind-proc w msg wparam lparam)
  (let ([wx (hwnd->wx w)])
    (if wx
        (send wx wndproc w msg wparam lparam DefWindowProcW)
        (DefWindowProcW w msg wparam lparam))))

(define wind-proc-ptr (function-ptr wind-proc _WndProc))

(define hInstance (GetModuleHandleW #f))

(define background-hbrush (let ([p (ptr-add #f (+ COLOR_BTNFACE 1))])
                            (cpointer-push-tag! p 'HBRUSH)
                            p))
 
(void (RegisterClassW (make-WNDCLASS CS_OWNDC
				     wind-proc-ptr
				     0
                                     0
				     hInstance
				     (LoadIconW hInstance "WXSTD_FRAME")
                                     #f
                                     background-hbrush
				     #f ; menu
				     "PLTFrame")))

(void (RegisterClassW (make-WNDCLASS 0 ; using CS_OWNDC creates trouble when resizing?
				     wind-proc-ptr
				     0
                                     0
				     hInstance
				     #f
                                     #f
                                     #f ; transparent
				     #f ; menu
				     "PLTCanvas")))

(void (RegisterClassW (make-WNDCLASS 0
				     wind-proc-ptr
				     0
                                     0
				     hInstance
				     #f
				     #f
                                     background-hbrush
				     #f ; menu
				     "PLTPanel")))

(define controls-are-transparent? #f)

(void (RegisterClassW (make-WNDCLASS 0
				     wind-proc-ptr
				     0
                                     0
				     hInstance
				     #f
				     #f
                                     (if controls-are-transparent?
                                         #f  ; transparent
                                         (let ([p (ptr-add #f (+ COLOR_BTNFACE 1))])
                                           (cpointer-push-tag! p 'HBRUSH)
                                           p))
				     #f ; menu
				     "PLTTabPanel")))

(define-user32 MessageBoxW (_fun _HWND _string/utf-16 _string/utf-16 _UINT -> _int))

(define (register-no-cursor orig-name)
  (let ([i (GetClassInfoW hInstance orig-name)])
    (set-WNDCLASS-lpszClassName! i (string-append "PLT" orig-name))
    (set-WNDCLASS-hCursor! i #f)
    (void (RegisterClassW i))))

(register-no-cursor "BUTTON")
(register-no-cursor "STATIC")
(register-no-cursor "LISTBOX")
(register-no-cursor "COMBOBOX")
(register-no-cursor "msctls_trackbar32")
(register-no-cursor "msctls_progress32")
(register-no-cursor "SysTabControl32")