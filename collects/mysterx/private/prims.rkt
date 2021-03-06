;; prims.ss

(module prims mzscheme
  (require "mxmain.ss")

  (provide 
   mx-version
   com-invoke
   com-set-property!
   com-get-property
   com-methods
   com-get-properties
   com-set-properties
   com-events	
   com-method-type
   com-get-property-type
   com-set-property-type
   com-event-type
   com-object-type
   com-is-a?
   com-date->date
   date->com-date
   com-date?
   com-currency?
   com-currency->number	
   number->com-currency
   com-scode?
   com-scode->number
   number->com-scode
   com-object?
   com-iunknown?
   com-help
   com-register-event-handler
   com-unregister-event-handler
   com-all-coclasses
   com-all-controls
   coclass->html
   progid->html
   cocreate-instance-from-coclass
   cocreate-instance-from-progid
   coclass
   progid
   set-coclass!
   set-coclass-from-progid!
   com-object-eq?
   com-register-object
   com-release-object
   com-add-ref
   com-ref-count
   make-browser
   browser-show
   navigate
   go-back
   go-forward
   refresh
   iconize
   restore
   register-navigate-handler
   current-url
   current-document	
   print
   document?
   document-title
   document-insert-html
   document-append-html
   document-replace-html
   document-find-element
   document-find-element-by-id-or-name
   document-elements-with-tag
   document-objects
   element-insert-html
   element-append-html
   element-replace-html
   element-get-html
   element-get-text
   element-insert-text
   element-append-text
   element-focus	
   element-selection
   element-set-selection!
   element-attribute
   element-set-attribute!
   element-click
   element-tag
   element-font-family
   element-set-font-family!
   element-font-style
   element-set-font-style!
   element-font-variant
   element-set-font-variant!
   element-font-weight
   element-set-font-weight!
   element-font
   element-set-font!
   element-background
   element-set-background!
   element-background-attachment
   element-set-background-attachment!
   element-background-image
   element-set-background-image!
   element-background-repeat
   element-set-background-repeat!
   element-background-position
   element-set-background-position!
   element-text-decoration
   element-set-text-decoration!
   element-text-transform
   element-set-text-transform!
   element-text-align
   element-set-text-align!
   element-margin
   element-set-margin!
   element-padding
   element-set-padding!
   element-border
   element-set-border!
   element-border-top
   element-set-border-top!
   element-border-bottom
   element-set-border-bottom!
   element-border-left
   element-set-border-left!
   element-border-right
   element-set-border-right!
   element-border-color
   element-set-border-color!
   element-border-width
   element-set-border-width!
   element-border-style
   element-set-border-style!
   element-border-top-style
   element-set-border-top-style!
   element-border-bottom-style
   element-set-border-bottom-style!
   element-border-left-style
   element-set-border-left-style!
   element-border-right-style
   element-set-border-right-style!
   element-style-float
   element-set-style-float!
   element-clear
   element-set-clear!
   element-display
   element-set-display!
   element-visibility
   element-set-visibility!
   element-list-style-type
   element-set-list-style-type!
   element-list-style-position
   element-set-list-style-position!
   element-list-style-image
   element-set-list-style-image!
   element-list-style
   element-set-list-style!
   element-position
   element-overflow
   element-set-overflow!
   element-pagebreak-before
   element-set-pagebreak-before!
   element-pagebreak-after
   element-set-pagebreak-after!
   element-css-text
   element-set-css-text!
   element-cursor
   element-set-cursor!
   element-clip
   element-set-clip!
   element-filter
   element-set-filter!
   element-style-string
   element-text-decoration-none
   element-set-text-decoration-none!
   element-text-decoration-underline
   element-set-text-decoration-underline!
   element-text-decoration-overline
   element-set-text-decoration-overline!
   element-text-decoration-linethrough
   element-set-text-decoration-linethrough!
   element-text-decoration-blink
   element-set-text-decoration-blink!
   element-pixel-top
   element-set-pixel-top!
   element-pixel-left
   element-set-pixel-left!
   element-pixel-width
   element-set-pixel-width!
   element-pixel-height
   element-set-pixel-height!
   element-pos-top
   element-set-pos-top!
   element-pos-left
   element-set-pos-left!
   element-pos-width
   element-set-pos-width!
   element-pos-height
   element-set-pos-height!
   element-font-size
   element-set-font-size!
   element-color
   element-set-color!
   element-background-color
   element-set-background-color!
   element-background-position-x
   element-set-background-position-x!
   element-background-position-y
   element-set-background-position-y!
   element-letter-spacing
   element-set-letter-spacing!
   element-vertical-align
   element-set-vertical-align!
   element-text-indent
   element-set-text-indent!
   element-line-height
   element-set-line-height!
   element-margin-top
   element-set-margin-top!
   element-margin-bottom
   element-set-margin-bottom!
   element-margin-left
   element-set-margin-left!
   element-margin-right
   element-set-margin-right!
   element-padding-top
   element-set-padding-top!
   element-padding-bottom
   element-set-padding-bottom!
   element-padding-left
   element-set-padding-left!
   element-padding-right
   element-set-padding-right!
   element-border-top-color
   element-set-border-top-color!
   element-border-bottom-color
   element-set-border-bottom-color!
   element-border-left-color
   element-set-border-left-color!
   element-border-right-color
   element-set-border-right-color!
   element-border-top-width
   element-set-border-top-width!
   element-border-bottom-width
   element-set-border-bottom-width!
   element-border-left-width
   element-set-border-left-width!
   element-border-right-width
   element-set-border-right-width!
   element-width
   element-set-width!
   element-height
   element-set-height!
   element-top
   element-set-top!
   element-left
   element-set-left!
   element-z-index
   element-set-z-index!
   event?
   get-event
   event-tag
   event-id
   event-from-tag
   event-from-id
   event-to-tag
   event-to-id
   event-keycode
   event-shiftkey
   event-ctrlkey
   event-altkey
   event-x
   event-y
   event-keypress?
   event-keydown?
   event-keyup?
   event-mousedown?
   event-mousemove?
   event-mouseover?
   event-mouseout?
   event-mouseup?
   event-click?
   event-dblclick?
   event-error?
   block-until-event
   process-win-events
   com-omit))
















