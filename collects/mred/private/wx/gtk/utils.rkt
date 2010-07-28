#lang scheme/base
(require ffi/unsafe
         ffi/unsafe/define
         "../common/utils.rkt"
         "types.rkt")

(provide define-gtk
         define-gdk
         define-gobj
         define-gio
         define-glib
         define-gdk_pixbuf
         define-mz

         g_object_ref
         g_object_unref

         g_object_set_data
         g_object_get_data
         g_signal_connect

         (rename-out [g_object_get g_object_get_window])

         get-gtk-object-flags
         set-gtk-object-flags!

         define-signal-handler)

(define gdk-lib 
  (case (system-type)
    [(windows) 
     (ffi-lib "libatk-1.0-0")
     (ffi-lib "libgio-2.0-0")
     (ffi-lib "libgdk_pixbuf-2.0-0")
     (ffi-lib "libgdk-win32-2.0-0")]
    [else (ffi-lib "libgdk-x11-2.0" '("0"))]))
(define gobj-lib 
  (case (system-type)
    [(windows)
     (ffi-lib "libgobject-2.0-0")]
    [else gdk-lib]))
(define glib-lib 
  (case (system-type)
    [(windows)
     (ffi-lib "libglib-2.0-0")]
    [else gdk-lib]))
(define gio-lib 
  (case (system-type)
    [(windows)
     (ffi-lib "libgio-2.0-0")]
    [else gdk-lib]))
(define gmodule-lib 
  (case (system-type)
    [(windows)
     (ffi-lib "libgmodule-2.0-0")]
    [else gdk-lib]))
(define gdk_pixbuf-lib 
  (case (system-type)
    [(windows)
     (ffi-lib "libgdk_pixbuf-2.0-0")]
    [else gdk-lib]))
(define gtk-lib
  (case (system-type)
    [(windows) 
     (ffi-lib "libgtk-win32-2.0-0")]
    [else (ffi-lib "libgtk-x11-2.0" '("0"))]))

(define-ffi-definer define-gtk gtk-lib)
(define-ffi-definer define-gobj gobj-lib)
(define-ffi-definer define-gio gio-lib)
(define-ffi-definer define-glib glib-lib)
(define-ffi-definer define-gmodule gmodule-lib)
(define-ffi-definer define-gdk gdk-lib)
(define-ffi-definer define-gdk_pixbuf gdk_pixbuf-lib)

(define-gobj g_object_ref (_fun _GtkWidget -> _void))
(define-gobj g_object_unref (_fun _GtkWidget -> _void))

(define-gobj g_object_set_data (_fun _GtkWidget _string _pointer -> _void))
(define-gobj g_object_get_data (_fun _GtkWidget _string -> _pointer))

(define-gobj g_signal_connect_data (_fun _gpointer _string _fpointer (_pointer = #f) _fnpointer _int -> _ulong))
(define (g_signal_connect obj s proc)
  (g_signal_connect_data obj s proc #f 0))

(define-gobj g_object_get (_fun _GtkWidget (_string = "window") 
				[w : (_ptr o _GdkWindow)]
				(_pointer = #f) -> _void -> w))

;; This seems dangerous, since the shape of GtkObject is not
;;  documented. But it seems to be the only way to get and set
;;  flags.
(define-cstruct _GtkObject ([type-instance _pointer]
                            [ref_count _uint]
                            [qdata _pointer]
                            [flags _uint32]))
(define (get-gtk-object-flags gtk)
  (GtkObject-flags (cast gtk _pointer _GtkObject-pointer)))
(define (set-gtk-object-flags! gtk v)
  (set-GtkObject-flags! (cast gtk _pointer _GtkObject-pointer) v))

(define-gmodule g_module_open (_fun _path _int -> _pointer))

(define-syntax-rule (define-signal-handler 
                      connect-name
                      signal-name
                      (_fun . args)
                      proc)
  (begin
    (define handler-proc proc)
    (define handler_function
      (function-ptr handler-proc (_fun #:atomic? #t . args)))
    (define (connect-name gtk)
      (g_signal_connect gtk signal-name handler_function))))