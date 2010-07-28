#lang scheme/base
(require scheme/class
         scheme/foreign
          "../../syntax.rkt"
         "item.rkt"
         "utils.rkt"
         "types.rkt"
         "widget.rkt"
         "window.rkt"
         "pixbuf.rkt"
         "../common/event.rkt"
         "../../lock.rkt")
(unsafe!)

(provide radio-box%)

;; ----------------------------------------

(define _GSList (_cpointer/null 'GSList))

(define-gtk gtk_radio_button_new_with_label (_fun _GSList _string -> _GtkWidget))
(define-gtk gtk_radio_button_new (_fun _GSList -> _GtkWidget))
(define-gtk gtk_radio_button_get_group (_fun _GtkWidget -> _GSList))
(define-gtk gtk_radio_button_set_group (_fun _GtkWidget _GSList -> _void))
(define-gtk gtk_toggle_button_set_active (_fun _GtkWidget _gboolean -> _void))
(define-gtk gtk_toggle_button_get_active (_fun _GtkWidget -> _gboolean))
(define-gtk gtk_widget_is_focus (_fun _GtkWidget -> _gboolean))

(define-signal-handler connect-clicked "clicked"
  (_fun _GtkWidget -> _void)
  (lambda (gtk)
    (let ([wx (gtk->wx gtk)])
      (send wx queue-clicked))))

(defclass radio-box% item%
  (init parent cb label
        x y w h
        labels
        val
        style
        font)
  (inherit set-auto-size
           on-set-focus)

  (define gtk (gtk_vbox_new #f 0))
  (define radio-gtks (for/list ([lbl (in-list labels)])
                       (let ([radio-gtk (cond
                                         [(string? lbl)
                                          (gtk_radio_button_new_with_label #f lbl)]
                                         [(send lbl ok?)
                                          (let ([radio-gtk (gtk_radio_button_new #f)]
                                                [image-gtk (gtk_image_new_from_pixbuf 
                                                            (bitmap->pixbuf lbl))])
                                            (gtk_container_add radio-gtk image-gtk)
                                            (gtk_widget_show image-gtk)
                                            radio-gtk)]
                                         [else
                                          (gtk_radio_button_new_with_label #f "<bad bitmap>")])])
                         (gtk_box_pack_start gtk radio-gtk #t #t 0)
                         (gtk_widget_show radio-gtk)
                         radio-gtk)))
  (for ([radio-gtk (in-list (cdr radio-gtks))])
    (let ([g (gtk_radio_button_get_group (car radio-gtks))])
      (gtk_radio_button_set_group radio-gtk g)))
                    
  (super-new [parent parent]
             [gtk gtk]
             [extra-gtks radio-gtks]
             [callback cb]
             [no-show? (memq 'deleted style)])

  (set-auto-size)
  (for ([radio-gtk (in-list (cdr radio-gtks))])
    (connect-clicked radio-gtk))
  (for ([radio-gtk (in-list radio-gtks)])
    (connect-key-and-mouse radio-gtk)
    (connect-focus radio-gtk))

  (define callback cb)
  (define/public (clicked)
    (callback this (new control-event%
                        [event-type 'radio-box]
                        [time-stamp (current-milliseconds)])))
  (define no-clicked? #f)
  (define/public (queue-clicked)
    (unless no-clicked?
      (queue-window-event this (lambda () (clicked)))))

  (define/public (button-focus i)
    (if (= i -1)
        (or (for/or ([radio-gtk (in-list radio-gtks)]
                     [i (in-naturals)])
              (and (gtk_widget_is_focus radio-gtk)
                   i))
            0)
        (gtk_widget_grab_focus (list-ref radio-gtks i))))
  (define/override (set-focus)
    (button-focus (max 0 (set-selection))))
  (define/public (set-selection i)
    (as-entry
     (lambda ()
       (set! no-clicked? #t)
       (if (= i -1)
           (let ([i (get-selection)])
             (unless (= i -1)
               (gtk_toggle_button_set_active (list-ref radio-gtks i) #f)))
           (gtk_toggle_button_set_active (list-ref radio-gtks i) #t))
       (set! no-clicked? #f))))

  (define/public (get-selection)
    (or (for/or ([radio-gtk (in-list radio-gtks)]
                 [i (in-naturals)])
          (and (gtk_toggle_button_get_active radio-gtk)
               i))
        -1))

  (define count (length labels))
  (define/public (number) count))