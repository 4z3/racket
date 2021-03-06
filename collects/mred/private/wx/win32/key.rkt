#lang racket/base
(require racket/class
         ffi/unsafe
         "utils.rkt"
         "types.rkt"
         "const.rkt"
         "../common/event.rkt")

(provide
 (protect-out make-key-event
              generates-key-event?))

(define-user32 GetKeyState (_wfun _int -> _SHORT))
(define-user32 MapVirtualKeyW (_wfun _UINT _UINT -> _UINT))
(define-user32 VkKeyScanW (_wfun _WCHAR -> _SHORT))

(define (generates-key-event? msg)
  (let ([message (MSG-message msg)])
    (and (memq message (list WM_KEYDOWN WM_SYSKEYDOWN
                             WM_KEYUP WM_SYSKEYUP))
         (make-key-event #t 
                         (MSG-wParam msg)
                         (MSG-lParam msg)
                         #f
                         (or (= message WM_KEYUP)
                             (= message WM_SYSKEYUP))
			 (MSG-hwnd msg)))))

(define (THE_SCAN_CODE lParam)
  (bitwise-and (arithmetic-shift lParam -16) #x1FF))

(define generic_ascii_code (make-hasheq))

;; The characters in find_shift_alts are things that we'll try
;; to include in keyboard events as char-if-Shift-weren't-pressed,
;; char-if-AltGr-weren't-pressed, etc.
(define other-key-codes
  (let ([find_shift_alts (string-append
                          "!@#$%^&*()_+-=\\|[]{}:\";',.<>/?~`"
                          "abcdefghijklmnopqrstuvwxyz"
                          "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                          "0123456789")])
    (list->vector
     (for/list ([i (in-string find_shift_alts)])
       (VkKeyScanW (char->integer i))))))

;; If a virtual key code has no mapping here, then the key should be
;; ignored by WM_KEYDOWN and processed by WM_CHAR instead
(define win32->symbol
  (hasheq VK_CANCEL 'cancel
          VK_BACK 'back
          VK_TAB 'tab
          VK_CLEAR 'clear
          VK_RETURN 'return
          VK_SHIFT 'shift
          VK_CONTROL 'control
          VK_MENU  'menu
          VK_PAUSE 'pause
          VK_SPACE 'space
          VK_ESCAPE 'escape
          VK_PRIOR 'prior
          VK_NEXT  'next
          VK_END 'end
          VK_HOME  'home
          VK_LEFT  'left
          VK_UP 'up
          VK_RIGHT 'right
          VK_DOWN  'down
          VK_SELECT 'select
          VK_PRINT 'print
          VK_EXECUTE 'execute
          VK_INSERT 'insert
          VK_DELETE 'delete
          VK_HELP  'help
          VK_NUMPAD0 'numpad0
          VK_NUMPAD1 'numpad1
          VK_NUMPAD2 'numpad2
          VK_NUMPAD3 'numpad3
          VK_NUMPAD4 'numpad4
          VK_NUMPAD5 'numpad5
          VK_NUMPAD6 'numpad6
          VK_NUMPAD7 'numpad7
          VK_NUMPAD8 'numpad8
          VK_NUMPAD9 'numpad9
          VK_MULTIPLY 'multiply
          VK_ADD 'add
          VK_SUBTRACT 'subtract
          VK_DECIMAL 'decimal
          VK_DIVIDE 'divide
          VK_F1 'f1
          VK_F2 'f2
          VK_F3 'f3
          VK_F4 'f4
          VK_F5 'f5
          VK_F6 'f6
          VK_F7 'f7
          VK_F8 'f8
          VK_F9 'f9
          VK_F10 'f10
          VK_F11 'f11
          VK_F12 'f12
          VK_F13 'f13
          VK_F14 'f14
          VK_F15 'f15
          VK_F16 'f16
          VK_F17 'f17
          VK_F18 'f18
          VK_F19 'f19
          VK_F20 'f20
          VK_F21 'f21
          VK_F22 'f22
          VK_F23 'f23
          VK_F24 'f24
          VK_NUMLOCK 'numlock
          VK_SCROLL 'scroll))


(define (make-key-event just-check? wParam lParam is-char? is-up? hwnd)
  (let ([control-down? (not (zero? (arithmetic-shift (GetKeyState VK_CONTROL) -1)))]
        [shift-down? (not (zero? (arithmetic-shift (GetKeyState VK_SHIFT) -1)))]
        [caps-down? (not (zero? (arithmetic-shift (GetKeyState VK_CAPITAL) -1)))]
        [alt-down? (= (bitwise-and (HIWORD lParam) KF_ALTDOWN) KF_ALTDOWN)])
    (let-values ([(id other-shift other-altgr other-shift-altgr)
                  (if is-char?
                      ;; wParam is a character
                      (let ([id wParam]
                            [sc (THE_SCAN_CODE lParam)])
                        ;; Remember scan codes to help with some key-release events:
                        (when (byte? id)
                          (hash-set! generic_ascii_code id sc))
                        ;; Look for elements of find_shift_alts that have a different
                        ;; shift/AltGr state:
                        (let ([k (MapVirtualKeyW sc 1)])
                          (if (zero? k)
                              (values (integer->char id) #f #f #f)
                              (for/fold ([id id][s #f][a #f][sa #f]) ([o (in-vector other-key-codes)]
                                                                      [j (in-naturals)])
                                (if (= (bitwise-and o #xFF) k)
                                    ;; Figure out whether it's different in the shift
                                    ;; for AltGr dimension, or both:
                                    (if (eq? (zero? (bitwise-and o #x100)) shift-down?)
                                        ;; different Shift
                                        (if (eq? (= (bitwise-and o #x600) #x6000)
                                                 (and control-down? alt-down?))
                                            ;; same AltGr
                                            (values id o a sa)
                                            ;; different AltGr
                                            (values id s a o))
                                        ;; same Shift
                                        (if (eq? (= (bitwise-and o #x600) #x6000)
                                                 (and control-down? alt-down?))
                                            ;; same AltGr
                                            (values id s a sa)
                                            ;; different AltGr
                                            (values id s o sa)))
                                    (values id s a sa))))))
                      ;; wParam is a virtual key code
                      (let ([id (hash-ref win32->symbol wParam #f)]
                            [override-mapping? (and control-down? (not alt-down?))]
                            [try-generate-release
                             (lambda ()
                               (let ([sc (THE_SCAN_CODE lParam)])
                                 (for/fold ([id #f]) ([i (in-range 256)] #:when (not id))
                                   (and (equal? sc (hash-ref generic_ascii_code i #f))
                                        (let ([id i])
                                          (if (id . < . 127)
                                              (char->integer (char-downcase (integer->char id)))
                                              id))))))])
                        (if (not id)
                            (if (or override-mapping? is-up?)
                                ;; Non-AltGr Ctl- combination, or a release event: 
                                ;; map manually, because the default mapping is
                                ;; unsatisfactory
                                ;; Set id to the unshifted key:
                                (let* ([id (bitwise-and (MapVirtualKeyW wParam 2) #xFFFF)]
                                       [id (cond
                                            [(zero? id) #f]
                                            [(id . < . 128)
                                             (char->integer (char-downcase (integer->char id)))]
                                            [else id])])
                                  (let-values ([(s a sa)
                                                ;; Look for shifted alternate:
                                                (for/fold ([s #f][a #f][sa #f]) ([o (in-vector other-key-codes)]
                                                                                 [j (in-naturals)])
                                                  (if (= (bitwise-and o #xFF) wParam)
                                                      (if (not (zero? (bitwise-and o #x100)))
                                                          (if (= (bitwise-and o #x600) #x6000)
                                                              (values s a o)
                                                              (values o a sa))
                                                          (if (= (bitwise-and o #x600) #x6000)
                                                              (values s o sa)
                                                              (values s a sa)))
                                                      (values s a sa)))])
                                    (if (and id shift-down?)
                                        ;; shift was pressed, so swap role of shifted and unshifted
                                        (values s id sa a)
                                        (values id s a sa))))
                                (values (and is-up? (try-generate-release)) #f #f #f))
                            (cond
                             [(and (not is-up?) (= wParam VK_CONTROL))
                              ;; Don't generate control-key down events:
                              (values #f #f #f #f)]
                             [(and (not override-mapping?) (not is-up?)
                                   ;; Let these get translated to WM_CHAR or skipped
                                   ;; entirely:
                                   (memq wParam
                                         (list VK_ESCAPE VK_SHIFT VK_CONTROL
                                               VK_SPACE VK_RETURN VK_TAB VK_BACK)))
                              (values #f #f #f #f)]
                             [(and (not id) is-up?)
                              (values (try-generate-release) #f #f #f)]
                             [else
                              (values id #f #f #f)]))))])
      (and id
           (if just-check?
               #t
               (let* ([id (if (number? id) (integer->char id) id)]
                      [e (new key-event%
                              [key-code (if is-up?
                                           'release
                                           (if (equal? id #\033)
                                               'escape
                                               id))]
                              [shift-down shift-down?]
                              [control-down control-down?]
                              [meta-down #f]
                              [alt-down alt-down?]
                              [x 0]
                              [y 0]
                              [time-stamp 0]
                              [caps-down caps-down?])])
                 e))))))

