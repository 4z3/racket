#lang scheme/base
(require scheme/class
          "../../syntax.rkt")

(provide window%)

(defclass window% object%
  (def/public-unimplemented on-drop-file)
  (def/public-unimplemented pre-on-event)
  (def/public-unimplemented pre-on-char)
  (def/public-unimplemented on-size)
  (def/public-unimplemented on-set-focus)
  (def/public-unimplemented on-kill-focus)
  (def/public-unimplemented get-handle)
  (def/public-unimplemented is-enabled-to-root?)
  (def/public-unimplemented is-shown-to-root?)
  (def/public-unimplemented set-phantom-size)
  (def/public-unimplemented get-y)
  (def/public-unimplemented get-x)
  (def/public-unimplemented get-width)
  (def/public-unimplemented get-height)
  (def/public-unimplemented popup-menu)
  (def/public-unimplemented center)
  (def/public-unimplemented get-parent)
  (def/public-unimplemented refresh)
  (def/public-unimplemented screen-to-client)
  (def/public-unimplemented client-to-screen)
  (def/public-unimplemented drag-accept-files)
  (def/public-unimplemented enable)
  (def/public-unimplemented get-position)
  (def/public-unimplemented get-client-size)
  (def/public-unimplemented get-size)
  (def/public-unimplemented fit)
  (def/public-unimplemented is-shown?)
  (def/public-unimplemented show)
  (def/public-unimplemented set-cursor)
  (def/public-unimplemented move)
  (def/public-unimplemented set-size)
  (def/public-unimplemented set-focus)
  (def/public-unimplemented gets-focus?)
  (def/public-unimplemented centre)
  (super-new))