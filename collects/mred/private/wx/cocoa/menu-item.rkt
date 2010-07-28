#lang scheme/base
(require scheme/class
         scheme/foreign
         ffi/objc
         "../../syntax.rkt"
         "utils.rkt"
         "types.rkt"
         "const.rkt")
(unsafe!)
(objc-unsafe!)

(provide menu-item%)

(import-class NSMenuItem)

(define-objc-class MyMenuItem NSMenuItem
  [wx]
  (-a _void (selected: [_id sender]) (send wx selected)))


(defclass menu-item% object%
  (define/public (id) this)
  
  (define parent #f)
  (define/public (selected)
    ;; called in Cocoa thread
    (send parent item-selected this))

  (define/public (set-parent p)
    (set! parent p))

  (define label #f)
  (define/public (set-label l) (set! label l))
  (define/public (get-label) label)

  (define checked? #f)
  (define/public (set-checked c?) (set! checked? c?))
  (define/public (get-checked) checked?)

  (define enabled? #t)
  (define/public (set-enabled-flag e?) (set! enabled? e?))
  (define/public (get-enabled-flag) enabled?)

  (define/public (install menu)
    (let ([item (tell (tell MyMenuItem alloc) 
                      initWithTitle: #:type _NSString (regexp-replace #rx"\t.*" label "")
                      action: #:type _SEL #f
                      keyEquivalent: #:type _NSString "")])
      (set-ivar! item wx this)
      (tellv menu addItem: item)
      (tellv item setEnabled: #:type _BOOL enabled?)
      (tellv item setTarget: item)
      (tellv item setAction: #:type _SEL (selector selected:))
      (let ([shortcut (regexp-match #rx"\tCut=(.)(.*)" label)])
        (when shortcut
          (let* ([s (string-downcase (string (integer->char (string->number (caddr shortcut)))))]
                 [flags (- (char->integer (string-ref (cadr shortcut) 0))
                           (char->integer #\A))]
                 [mods (+ (if (positive? (bitwise-and flags 1))
                              NSShiftKeyMask
                              0)
                          (if (positive? (bitwise-and flags 2))
                              NSAlternateKeyMask
                              0)
                          (if (positive? (bitwise-and flags 4))
                              NSControlKeyMask
                              0)
                          (if (positive? (bitwise-and flags 8))
                              0
                              NSCommandKeyMask))])
            (tellv item setKeyEquivalent: #:type _NSString s)
            (tellv item setKeyEquivalentModifierMask: #:type _NSUInteger mods))))
      (tellv item release)))

  (super-new))