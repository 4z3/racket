#lang scribble/doc
@(require "common.ss")

@defclass/title[combo-field% text-field% ()]{

A @scheme[combo-field%] object is a @scheme[text-field%]
 object that also resembles a @scheme[choice%] object, because it
 has a small popup button to the right of the text field. Clicking 
 the button pops up a menu, and selecting a menu item typically copies
 the item into the text field.




@defconstructor[([label (or/c label-string? false/c)]
                 [choices (listof label-string?)]
                 [parent (or/c (is-a?/c frame%) (is-a?/c dialog%) 
                               (is-a?/c panel%) (is-a?/c pane%))]
                 [callback ((is-a?/c combo-field%) (is-a?/c control-event%) . -> . any) 
                           (lambda (c e) (void))]
                 [init-value string ""]
                 [style (listof (one-of/c 'horizontal-label 'vertical-label 
                                          'deleted)) 
                        null]
                 [font (is-a?/c font%) normal-control-font]
                 [enabled any/c #t]
                 [vert-margin (integer-in 0 1000) 2]
                 [horiz-margin (integer-in 0 1000) 2]
                 [min-width (integer-in 0 10000) _graphical-minimum-width]
                 [min-height (integer-in 0 10000) _graphical-minimum-height]
                 [stretchable-width any/c #t]
                 [stretchable-height any/c #f])]{

If @scheme[label] is not @scheme[#f], it is used as the combo label.
 Otherwise, the combo does not display its label.

@labelstripped[(scheme label) @elem{} @elem{move the keyboard focus to the combo}]

The @scheme[choices] list specifies the initial list of items for the
 combo's popup menu. The
@method[combo-field% append] method adds a new item to the menu with a callback to install the
 appended item into the combo's text field. The
@method[combo-field% get-menu] method returns a menu that can be changed to
 adjust the content and actions of the combo's menu.

The @scheme[callback] procedure is called when the user changes the text
 in the combo or presses the Enter key (and Enter is not handled by
 the combo's frame or dialog; see
@xmethod[top-level-window<%> on-traverse-char] ). If the user presses Enter, the type of event passed to the callback
 is @indexed-scheme['text-field-enter], otherwise it is
 @indexed-scheme['text-field].

If @scheme[init-value] is not @scheme[""], the minimum width of the text item
 is made wide enough to show @scheme[init-value]. Otherwise, a built-in
 default width is selected.

@HVLabelNote[@scheme[style]]{combo} @DeletedStyleNote[@scheme[style] @scheme[parent]]{combo}.

@FontKWs[@scheme[font]] @WindowKWs[@scheme[enabled]] @SubareaKWs[] @AreaKWs[]


}


@defmethod[(append [l label-string?])
           void?]{

Adds a new item to the combo's popup menu. The given label is used for
 the item's name, and the item's callback installs the label into the
 combo's text field.

}


@defmethod[(get-menu)
           (is-a?/c popup-menu%)]{
Returns a @scheme[popup-menu%] that is effectively copied into the
 combo's popup menu when the combo is clicked. Only the labels can
 callbacks of the menu's items are used; the enable state, submenus,
 or separators are ignored.
}


@defmethod[(on-popup [event (is-a?/c control-event%)])
           void?]{

@methspec{

Called when the user clicks the combo's popup button. Override this method
to adjust the content of the combo menu on demand.

}
@methimpl{

Does nothing.

}}


}
