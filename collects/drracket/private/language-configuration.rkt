#lang racket/base
  (require (prefix-in : mred/mred) ;; ensure that this module is always loaded since it is shared below for pretty big
           racket/unit
           mrlib/hierlist
           racket/class
           racket/contract
           racket/string
           racket/list
           racket/gui/base
           "drsig.rkt"
           string-constants
           framework
           setup/getinfo
           syntax/toplevel
           (only-in mzlib/struct make-->vector))
  
  (define original-output (current-output-port))
  (define (oprintf . args) (apply fprintf original-output args))
  
  (define-values (sc-use-language-in-source sc-choose-a-language mouse-event-uses-shortcut-prefix?)
    (let* ([shortcut-prefix (get-default-shortcut-prefix)]
           [menukey-string 
            (apply string-append
                   (map (λ (x)
                          (case x
                            [(cmd) "⌘"]
                            [else (format "~a-" x)]))
                        shortcut-prefix))])
      (define (mouse-event-uses-shortcut-prefix? evt)
        (andmap (λ (prefix)
                  (case prefix
                    [(alt) (case (system-type)
                             [(windows) (send evt get-meta-down)]
                             [else (send evt get-alt-down)])]
                    [(cmd) (send evt get-meta-down)]
                    [(meta) (send evt get-meta-down)]
                    [(ctl) (send evt get-control-down)]
                    [(shift) (send evt get-shiftdown)]
                    [(option) (send evt get-alt-down)]))
                shortcut-prefix))
    (values (string-append (string-constant use-language-in-source)
                           (format " (~aU)" menukey-string))
            (string-append (string-constant choose-a-language)
                           (format " (~aC)" menukey-string))
            mouse-event-uses-shortcut-prefix?)))
  
  (define sc-lang-in-source-discussion (string-constant lang-in-source-discussion))

  (provide language-configuration@)
  
  (define-unit language-configuration@
    (import [prefix drracket:unit: drracket:unit^]
            [prefix drracket:rep: drracket:rep^]
            [prefix drracket:init: drracket:init^]
            [prefix drracket:language: drracket:language^]
            [prefix drracket:app: drracket:app^]
            [prefix drracket:tools: drracket:tools^]
            [prefix drracket:help-desk: drracket:help-desk^]
            [prefix drracket:module-language: drracket:module-language^])
    (export drracket:language-configuration/internal^)
    
    ;; settings-preferences-symbol : symbol
    ;; this pref used to depend on `version', but no longer does.
    (define settings-preferences-symbol 'drracket:language-settings)
    
    ;; get-settings-preferences-symbol : -> symbol
    (define (get-settings-preferences-symbol) settings-preferences-symbol)
    
    ;; default-language-position : (listof string)
    ;; if a language is registered with this position, it is
    ;; considered the default language
    (define initial-language-position
      (list (string-constant initial-language-category)
            (string-constant no-language-chosen)))
    
    ;; languages : (listof (instanceof language<%>))
    ;; all of the languages supported in DrRacket
    (define languages null)
    
    ;; add-language : (instanceof language%) -> void
    ;; only allows addition on phase2
    ;; effect: updates `languages'
    (define add-language
      (λ (language [front? #f])
        
        (drracket:tools:only-in-phase 'drracket:language:add-language 'phase2)
        (for-each
         (λ (i<%>)
           (unless (is-a? language i<%>)
             (error 'drracket:language:add-language "expected language ~e to implement ~e, forgot to use `drracket:language:get-default-mixin'?" language i<%>)))
         (drracket:language:get-language-extensions))
        
        (ensure-no-duplicate-numbers language languages)
        (set! languages 
              (if front? 
                  (cons language languages)
                  (append languages (list language))))))
    
    (define (ensure-no-duplicate-numbers l1 languages)
      (for-each
       (λ (l2)
         (when (equal? (send l1 get-language-numbers)
                       (send l2 get-language-numbers))
           (error 'drracket:language-configuration:add-language
                  "found two languages with the same result from get-language-numbers: ~s, ~s and ~s"
                  (send l1 get-language-numbers)
                  (send l1 get-language-position)
                  (send l2 get-language-position))))
       languages))
    
    ;; get-languages : -> (listof languages)
    (define (get-languages) 
      (drracket:tools:only-in-phase
       'drracket:language-configuration:get-languages
       'init-complete)
      languages)
    
    ;; get-default-language-settings : -> language-settings
    ;; uses `default-language-position' to find the default language.
    ;; if that language is not available, just takes the first language.
    ;; if there are no languages defined yet, signal an error -- drscheme is in trouble.
    (define (get-default-language-settings)
      (when (null? languages)
        (error 'get-default-language-settings "no languages registered!"))
      (let ([lang (or (ormap (λ (x)
                               (and (equal? (send x get-language-position)
                                            initial-language-position)
                                    x))
                             (get-languages))
                      (list-ref (get-languages) 0))])
        (language-settings lang (send lang default-settings))))
    
    ;; type language-settings = (language-settings (instanceof language<%>) settings)
    (define-struct language-settings (language settings))
    
    
    ;                                                                                                      
    ;                                                                                                      
    ;                                                                                                      
    ;   ;                                                                ;   ;          ;                  
    ;   ;                                                                ;              ;                  
    ;   ;                                                                ;              ;                  
    ;   ;   ;;;    ; ;;     ;; ;   ;   ;   ;;;     ;; ;    ;;;        ;; ;   ;   ;;;    ;    ;;;     ;; ;  
    ;   ;  ;   ;   ;;  ;   ;  ;;   ;   ;  ;   ;   ;  ;;   ;   ;      ;  ;;   ;  ;   ;   ;   ;   ;   ;  ;;  
    ;   ;      ;   ;   ;  ;    ;   ;   ;      ;  ;    ;  ;    ;     ;    ;   ;      ;   ;  ;     ; ;    ;  
    ;   ;   ;;;;   ;   ;  ;    ;   ;   ;   ;;;;  ;    ;  ;;;;;;     ;    ;   ;   ;;;;   ;  ;     ; ;    ;  
    ;   ;  ;   ;   ;   ;  ;    ;   ;   ;  ;   ;  ;    ;  ;          ;    ;   ;  ;   ;   ;  ;     ; ;    ;  
    ;   ;  ;   ;   ;   ;   ;  ;;   ;  ;;  ;   ;   ;  ;;   ;          ;  ;;   ;  ;   ;   ;   ;   ;   ;  ;;  
    ;   ;   ;;;;;  ;   ;    ;; ;    ;; ;   ;;;;;   ;; ;    ;;;;       ;; ;   ;   ;;;;;  ;    ;;;     ;; ;  
    ;                          ;                      ;                                                 ;  
    ;                     ;    ;                 ;    ;                                            ;    ;  
    ;                      ;;;;                   ;;;;                                              ;;;;   
    
    
    ;; language-dialog : (boolean language-setting -> (union #f language-setting))
    ;;                   (boolean language-setting (union #f (instanceof top-level-window%))
    ;;                    -> 
    ;;                    (union #f language-setting))
    ;; allows the user to configure their language. The input language-setting is used
    ;; as the defaults in the dialog and the output language setting is the user's choice
    ;; todo: when button is clicked, ensure language is selected
    (define language-dialog
      (λ (show-welcome? language-settings-to-show [parent #f])
        (define ret-dialog%
          (class dialog%
            (define/override (on-subwindow-char receiver evt)
              (case (send evt get-key-code)
                [(escape) (cancel-callback)]
                [(#\return numpad-enter) (enter-callback)]
                [else
                 (or (key-pressed receiver evt)
                     (super on-subwindow-char receiver evt))]))
            (super-instantiate ())))
        
        (define dialog (instantiate ret-dialog% ()
                         (label (if show-welcome?
                                    (string-constant welcome-to-drscheme)
                                    (string-constant language-dialog-title)))
                         (parent parent)
                         (style '(resize-border))))
        (define welcome-before-panel (instantiate horizontal-pane% ()
                                       (parent dialog)
                                       (stretchable-height #f)))
        (define language-dialog-meat-panel (make-object vertical-pane% dialog))
        
        (define welcome-after-panel (instantiate vertical-pane% () 
                                      (parent dialog)
                                      (stretchable-height #f)))
        
        (define button-panel (instantiate horizontal-pane% ()
                               (parent dialog)
                               (stretchable-height #f)))
        
        ;; initialized below
        (define ok-button #f)
        (define cancel-button #f)
        
        ;; cancelled? : boolean
        ;; flag that indicates if the dialog was cancelled.
        (define cancelled? #t)
        
        ;; enter-callback : -> bool
        ;; returns #f if no language is selected (so the event will be
        ;; processed by the hierlist widget, which will toggle subtrees)
        (define (enter-callback)
          (cond [(get-selected-language)
                 (set! cancelled? #f)
                 (send dialog show #f)]
                [else #f]))
        
        ;; ok-callback : -> void
        ;; similar to the above, but shows an error dialog if no language os
        ;; selected
        (define (ok-callback)
          (unless (enter-callback)
            (message-box (string-constant drscheme)
                         (string-constant please-select-a-language))))
        
        ;; cancel-callback : -> void
        (define (cancel-callback)
          (send dialog show #f))
        
        ;; a handler for "ok"-related stuff
        (define ok-handler
          ;; this is called before the buttons are made: keep track of state
          ;; in that case
          (let ([enabled? #t])
            (define (enable! state)
              (set! enabled? state)
              (when ok-button (send ok-button enable state)))
            (λ (msg)
              (case msg
                [(disable)     (enable! #f)]
                [(enable)      (enable! #t)]
                [(enable-sync) (enable! enabled?)]
                [(execute)     (enter-callback) (void)]
                [else (error 'ok-handler "internal error (~e)" msg)]))))
        
        (define-values (get-selected-language get-selected-language-settings key-pressed)
          (fill-language-dialog language-dialog-meat-panel
                                button-panel
                                language-settings-to-show
                                #f
                                ok-handler))
        
        ;; create ok/cancel buttons
        (make-object horizontal-pane% button-panel)
        (set!-values (ok-button cancel-button)
                     (gui-utils:ok/cancel-buttons button-panel
                                                  (λ (x y) (ok-callback))
                                                  (λ (x y) (cancel-callback))))
        (ok-handler 'enable-sync) ; sync enable status now
        (make-object grow-box-spacer-pane% button-panel)
        
        (when show-welcome?
          (add-welcome dialog welcome-before-panel welcome-after-panel))
        
        (send dialog stretchable-width #f)
        (send dialog stretchable-height #t)
        
        (unless parent
          (send dialog center 'both))
        (send dialog show #t)
        (if cancelled?
            #f
            (language-settings
             (get-selected-language)
             (get-selected-language-settings)))))
    
    ;; fill-language-dialog :    (vertical-panel panel language-setting -> language-setting)
    ;;                           (union dialog #f) [...more stuff...]
    ;;                        -> (-> (union #f language<%>)) (-> settings[corresponding to fst thnk result])
    ;; allows the user to configure their language. The input language-setting is used
    ;; as the defaults in the dialog and the output language setting is the user's choice
    ;; if re-center is a dialog, when the show details button is clicked, the dialog is recenterd.
    (define fill-language-dialog
      (λ (parent show-details-parent language-settings-to-show
                          [re-center #f]
                          [ok-handler void]) ; en/disable button, execute it
        
        (define-values (language-to-show settings-to-show)
          (let ([request-lang-to-show (language-settings-language language-settings-to-show)])
            (cond
              [(equal? initial-language-position (send request-lang-to-show get-language-position))
               (values (list-ref (get-languages) 0)
                       (send (list-ref (get-languages) 0) default-settings))
               (values #f #f)]
              [else (values request-lang-to-show
                            (language-settings-settings language-settings-to-show))])))
        
        ;; hier-list items that implement this interface correspond to
        ;; actual language selections
        (define hieritem-language<%>
          (interface (hierarchical-list-item<%>)
            get-language
            selected))
        
        (define selectable-hierlist%
          (class hierarchical-list%
            (init parent)
            
            (inherit get-selected)
            (define/override (on-char evt)
              (let ([code (send evt get-key-code)])
                (case code
                  [(up)   (select-next sub1)]
                  [(down) (select-next add1)]
                  ;; right key is fine, but nicer to close after a left
                  [(left) (super on-char evt)
                          (cond [(get-selected)
                                 => (λ (i)
                                      (when (is-a? i hierarchical-list-compound-item<%>)
                                        (send i close)))])]
                  [else (super on-char evt)])))
            
            (inherit get-items)
            
            ;; select-next : (num -> num) -> void
            ;; finds the next/prev leaf after the selected child on the open
            ;; fringe using `inc' for a direction.
            (define/private (select-next inc)
              (define current (get-selected))
              (define (choose item)
                (when current (send current select #f))
                (send item select #t)
                ;; make it visible
                (let loop ([item item])
                  (let ([parent (send item get-parent)])
                    (if parent
                        (loop parent)
                        (send item scroll-to))))
                (send item scroll-to))
              (define (selectable? item)
                (and (send item get-allow-selection?)
                     ;; opened all the way to the top
                     (let loop ([p (send item get-parent)])
                       (or (not p)
                           (and (send p is-open?)
                                (loop (send p get-parent)))))))
              (let* ([fringe     (get-fringe)]
                     [fringe-len (vector-length fringe)]
                     [n (if current
                            (let loop ([i (sub1 (vector-length fringe))])
                              (cond [(< i 0) (error 'select-next "item not found in fringe")]
                                    [(eq? current (vector-ref fringe i))
                                     (min (sub1 fringe-len) (max 0 (inc i)))]
                                    [else (loop (sub1 i))]))
                            (modulo (inc fringe-len) (add1 fringe-len)))])
                ;; need to choose item n, but go on looking for one that is
                ;; selectable and open
                (let loop ([n n])
                  (when (< -1 n fringe-len)
                    (let ([item (vector-ref fringe n)])
                      (if (selectable? item)
                          (choose item)
                          (loop (inc n))))))))
            
            (define cached-fringe #f)
            (define/public (clear-fringe-cache) (set! cached-fringe #f))
            (define (get-fringe)
              (unless cached-fringe
                (let ([fringe
                       (let loop ([items (get-items)])
                         (apply append
                                (map (λ (item)
                                       (if (is-a? item hierarchical-list-compound-item<%>)
                                           (cons item
                                                 (loop (send item get-items)))
                                           (list item)))
                                     items)))])
                  (set! cached-fringe (list->vector fringe))))
              cached-fringe)
            
            (define/override (on-select i)
              (cond
                [(and i (is-a? i hieritem-language<%>))
                 (preferences:set 'drracket:language-dialog:hierlist-default (send (send i get-language) get-language-position))
                 (set! most-recent-languages-hier-list-selection i)
                 (something-selected i)]
                [else
                 (non-language-selected)]))
            ;; this is used only because we set `on-click-always'
            (define/override (on-click i)
              (when (and i (is-a? i hierarchical-list-compound-item<%>))
                (send i toggle-open/closed)))
            ;; double-click selects a language
            (define/override (on-double-select i)
              (when (and i (is-a? i hieritem-language<%>))
                (something-selected i)
                (ok-handler 'execute)))
            (super-new [parent parent])
            ;; do this so we can expand/collapse languages on a single click
            (inherit on-click-always allow-deselect)
            (on-click-always #t)
            (allow-deselect #t)))
        
        (define outermost-panel (new horizontal-pane% [parent parent]))
        (define languages-choice-panel (new vertical-panel%
                                            [parent outermost-panel]
                                            [alignment '(left top)]))
        
        (define use-language-in-source-rb
          (new radio-box% 
               [label #f]
               [choices (list sc-use-language-in-source)]
               [parent languages-choice-panel]
               [callback
                (λ (rb evt)
                  (use-language-in-source-rb-callback))]))
        (define (use-language-in-source-rb-callback)
          (module-language-selected)
          (send use-chosen-language-rb set-selection #f))
        (define in-source-discussion-panel (new horizontal-panel% 
                                                [parent languages-choice-panel]
                                                [stretchable-height #f]))
        (define in-source-discussion-spacer (new horizontal-panel% 
                                                 [parent in-source-discussion-panel]
                                                 [stretchable-width #f]
                                                 [min-width 32]))
        (define in-source-discussion-editor-canvas (add-discussion in-source-discussion-panel))
        (define most-recent-languages-hier-list-selection (preferences:get 'drracket:language-dialog:hierlist-default))
        (define use-chosen-language-rb
          (new radio-box%
               [label #f]
               [choices (list sc-choose-a-language)]
               [parent languages-choice-panel]
               [callback
                (λ (this-rb evt)
                  (use-chosen-language-rb-callback))]))
        (define (use-chosen-language-rb-callback)
          (when most-recent-languages-hier-list-selection
            (send languages-hier-list select 
                  most-recent-languages-hier-list-selection))
          (send use-language-in-source-rb set-selection #f)
          (send languages-hier-list focus))
        (define languages-hier-list-panel (new horizontal-panel% [parent languages-choice-panel]))
        (define languages-hier-list-spacer (new horizontal-panel% 
                                                [parent languages-hier-list-panel]
                                                [stretchable-width #f]
                                                [min-width 16]))
        
        (define languages-hier-list (new selectable-hierlist% 
                                         [parent languages-hier-list-panel]
                                         [style '(no-border no-hscroll auto-vscroll transparent)]))
        (define details-outer-panel (make-object vertical-pane% outermost-panel))
        (define details/manual-parent-panel (make-object vertical-panel% details-outer-panel))
        (define details-panel (make-object panel:single% details/manual-parent-panel))
        
        (define one-line-summary-message (instantiate message% ()
                                           (parent parent)
                                           (label "")
                                           (stretchable-width #t)))
        
        (define no-details-panel (make-object vertical-panel% details-panel))
        
        (define languages-table (make-hasheq))
        (define languages (get-languages))
        
        ;; selected-language : (union (instanceof language<%>) #f)
        ;; invariant: selected-language and get/set-selected-language-settings
        ;;            match the user's selection in the languages-hier-list.
        ;;            or #f if the user is not selecting a language.
        (define selected-language #f)
        ;; get/set-selected-language-settings (union #f (-> settings))
        (define get/set-selected-language-settings #f)
        
        (define details-computed? #f)
        
        ;; language-mixin : (implements language<%>) 
        ;;                  (-> (implements area-container<%>))
        ;;                  get/set 
        ;;                  ->
        ;;                  ((implements hierlist<%>) -> (implements hierlist<%>))
        ;; a mixin that responds to language selections and updates the details-panel
        (define (language-mixin language get-language-details-panel get/set-settings)
          (λ (%)
            (class* % (hieritem-language<%>)
              (init-rest args)
              (define/public (get-language) language)
              (define/public (selected)
                (update-gui-based-on-selected-language language get-language-details-panel get/set-settings))
              (apply super-make-object args))))
        
        (define (update-gui-based-on-selected-language language get-language-details-panel get/set-settings)
          (let ([ldp (get-language-details-panel)])
            (when ldp
              (send details-panel active-child ldp)))
          (send one-line-summary-message set-label (send language get-one-line-summary))
          (send revert-to-defaults-button enable #t)
          (set! get/set-selected-language-settings get/set-settings)
          (set! selected-language language))
        
        (define (module-language-selected)
          ;; need to deselect things in the languages-hier-list at this point.
          (send languages-hier-list select #f)
          (send use-chosen-language-rb set-selection #f)
          (send use-language-in-source-rb set-selection 0)
          (ok-handler 'enable)
          (send details-button enable #t)
          (update-gui-based-on-selected-language module-language*language
                                                 module-language*get-language-details-panel
                                                 module-language*get/set-settings))
        
        ;; no-language-selected : -> void
        ;; updates the GUI for the situation where no language at all selected, and
        ;; and thus neither of the radio buttons should be selected. 
        ;; this generally happens when there is no preference setting for the language
        ;; (ie the user has just started drracket for the first time)
        (define (no-language-selected)
          (non-language-selected)
          (send use-chosen-language-rb set-selection #f))
        
        (define module-language*language 'module-language*-not-yet-set)
        (define module-language*get-language-details-panel 'module-language*-not-yet-set)
        (define module-language*get/set-settings 'module-language*-not-yet-set)
        
        ;; non-language-selected : -> void
        ;; updates the GUI and selected-language and get/set-selected-language-settings
        ;; for when some non-language is selected in the hierlist
        (define (non-language-selected)
          (send use-chosen-language-rb set-selection 0)
          (send use-language-in-source-rb set-selection #f)
          (send revert-to-defaults-button enable #f)
          (send details-panel active-child no-details-panel)
          (send one-line-summary-message set-label "")
          (set! get/set-selected-language-settings #f)
          (set! selected-language #f)
          (ok-handler 'disable)
          (send details-button enable #f))
        
        ;; something-selected : item -> void
        (define (something-selected item)
          (send use-chosen-language-rb set-selection 0)
          (send use-language-in-source-rb set-selection #f)
          (ok-handler 'enable)                
          (send details-button enable #t)
          (send item selected))
        
        ;; construct-details : (union (-> void) #f)
        (define construct-details void)
        
        ;; add-language-to-dialog : (instanceof language<%>) -> void
        ;; adds the language to the dialog
        ;; opens all of the turn-down tags
        ;; when `language' matches language-to-show, update the settings
        ;;   panel to match language-to-show, otherwise set to defaults.
        (define (add-language-to-dialog language)
          (let ([positions (send language get-language-position)]
                [numbers (send language get-language-numbers)])
            
            ;; don't show the initial language ...
            (unless (equal? positions initial-language-position)
              (unless (and (list? positions)
                           (list? numbers)
                           (pair? positions)
                           (pair? numbers)
                           (andmap number? numbers)
                           (andmap string? positions)
                           (= (length positions) (length numbers))
                           ((length numbers) . >= . 1))
                (error 'drracket:language
                       "languages position and numbers must be lists of strings and numbers, respectively, must have the same length, and must each contain at least one element, got: ~e ~e"
                       positions numbers))
              
              (when (null? (cdr positions))
                (unless (equal? positions (list (string-constant module-language-name)))
                  (error 'drracket:language
                         "Only the module language may be at the top level. Other languages must have at least two levels")))
              
              (send languages-hier-list clear-fringe-cache)
              
              #|
              
              inline the first level of the tree into just items in the hierlist
              keep track of the starting (see call to sort method below) by
              adding a second field to the second level of the tree that indicates
              what the sorting number is for its level above (in the second-number mixin)
              
              |#
              
              (let add-sub-language ([ht languages-table]
                                     [hier-list languages-hier-list]
                                     [positions positions]
                                     [numbers numbers]
                                     [first? #t]
                                     [second-number #f]) ;; only non-#f during the second iteration in which case it is the first iterations number
                (cond
                  [(null? (cdr positions))
                   (let* ([language-details-panel #f]
                          [real-get/set-settings 
                           (case-lambda
                             [() 
                              (cond
                                [(and language-to-show 
                                      settings-to-show
                                      (equal? (send language-to-show get-language-position)
                                              (send language get-language-position)))
                                 settings-to-show]
                                [else
                                 (send language default-settings)])]
                             [(x) (void)])]
                          [get-language-details-panel (lambda () language-details-panel)]
                          [get/set-settings (lambda x (apply real-get/set-settings x))]
                          [position (car positions)]
                          [number (car numbers)])
                     
                     (set! construct-details
                           (let ([old construct-details])
                             (lambda ()
                               (old)
                               (let-values ([(language-details-panel-real get/set-settings)
                                             (make-details-panel language)])
                                 (set! language-details-panel language-details-panel-real)
                                 (set! real-get/set-settings get/set-settings))
                               
                               (let-values ([(vis-lang vis-settings)
                                             (cond
                                               [(and (not selected-language)
                                                     (eq? language-to-show language))
                                                (values language-to-show settings-to-show)]
                                               [(eq? selected-language language)
                                                (values language 
                                                        (if (eq? language language-to-show)
                                                            settings-to-show
                                                            (send language default-settings)))]
                                               [else (values #f #f)])])
                                 (cond
                                   [(and vis-lang
                                         (equal? (send vis-lang get-language-position)
                                                 (send language get-language-position)))
                                    (get/set-settings vis-settings)
                                    (send details-panel active-child language-details-panel)]
                                   [else
                                    (get/set-settings (send language default-settings))])))))
                     
                     (cond
                       [(equal? positions (list (string-constant module-language-name)))
                        (set! module-language*language language)
                        (set! module-language*get-language-details-panel get-language-details-panel)
                        (set! module-language*get/set-settings get/set-settings)]
                     [else
                      (let* ([mixin (compose
                                     number-mixin
                                     (language-mixin language get-language-details-panel get/set-settings))]
                             [item
                              (send hier-list new-item
                                    (if second-number
                                        (compose second-number-mixin mixin)
                                        mixin))]
                             [text (send item get-editor)]
                             [delta (send language get-style-delta)])
                        (send item set-number number)
                        (when second-number
                          (send item set-second-number second-number))
                        (send text insert position)
                        (when delta
                          (cond
                            [(list? delta)
                             (for-each (λ (x)
                                         (send text change-style 
                                               (car x)
                                               (cadr x)
                                               (caddr x)))
                                       delta)]
                            [(is-a? delta style-delta%)
                             (send text change-style 
                                   (send language get-style-delta)
                                   0
                                   (send text last-position))])))]))]
                  [else (let* ([position (car positions)]
                               [number (car numbers)]
                               [sub-ht/sub-hier-list
                                (hash-ref
                                 ht
                                 (string->symbol position)
                                 (λ ()
                                   (if first?
                                       (let* ([item (send hier-list new-item number-mixin)]
                                              [x (list (make-hasheq) hier-list item)])
                                         (hash-set! ht (string->symbol position) x)
                                         (send item set-number number)
                                         (send item set-allow-selection #f)
                                         (let* ([editor (send item get-editor)]
                                                [pos (send editor last-position)])
                                           (send editor insert "\n")
                                           (send editor insert position)
                                           (send editor change-style small-size-delta pos (+ pos 1))
                                           (send editor change-style section-style-delta 
                                                 (+ pos 1) (send editor last-position)))
                                         x)
                                       (let* ([new-list (send hier-list new-list
                                                              (if second-number
                                                                  (compose second-number-mixin number-mixin)
                                                                  number-mixin))]
                                              [x (list (make-hasheq) new-list #f)])
                                         (send new-list set-number number)
                                         (when second-number
                                           (send new-list set-second-number second-number))
                                         (send new-list set-allow-selection #t)
                                         (send new-list open)
                                         (send (send new-list get-editor) insert position)
                                         (hash-set! ht (string->symbol position) x)
                                         x))))])
                          (cond
                            [first? 
                             (unless (= number (send (caddr sub-ht/sub-hier-list) get-number))
                               (error 'add-language "language ~s; expected number for ~e to be ~e, got ~e"
                                      (send language get-language-name)
                                      position
                                      (send (caddr sub-ht/sub-hier-list) get-number)
                                      number))]
                            [else
                             (unless (= number (send (cadr sub-ht/sub-hier-list) get-number))
                               (error 'add-language "language ~s; expected number for ~e to be ~e, got ~e"
                                      (send language get-language-name)
                                      position
                                      (send (cadr sub-ht/sub-hier-list) get-number)
                                      number))])
                          (add-sub-language (car sub-ht/sub-hier-list)
                                            (cadr sub-ht/sub-hier-list)
                                            (cdr positions)
                                            (cdr numbers)
                                            #f
                                            (if first? number #f)))])))))
        
        (define number<%>
          (interface ()
            get-number
            set-number))
        
        (define second-number<%>
          (interface ()
            get-second-number
            set-second-number))
        
        ;; number-mixin : (extends object%) -> (extends object%)
        ;; adds the get/set-number methods to this class
        (define (number-mixin %)
          (class* % (number<%>)
            (field (number 0))
            (define/public (get-number) number)
            (define/public (set-number _number) (set! number _number))
            (super-instantiate ())))
        
        ;; second-number-mixin : (extends object%) -> (extends object%)
        ;; adds the get/set-second-number methods to this class
        (define (second-number-mixin %)
          (class* % (second-number<%>)
            (field (second-number 0))
            (define/public (get-second-number) second-number)
            (define/public (set-second-number _second-number) (set! second-number _second-number))
            (super-instantiate ())))
        
        ;; make-details-panel : ((instanceof language<%>) -> (values panel (case-> (-> settings) (settings -> void))))
        ;; adds a details panel for `language', using
        ;; the language's default settings, unless this is
        ;; the to-show language.
        (define (make-details-panel language)
          (let ([panel (instantiate vertical-panel% ()
                         (parent details-panel)
                         (stretchable-width #f)
                         (stretchable-height #f))])
            (values
             panel
             (send language config-panel panel))))
        
        ;; close-all-languages : -> void
        ;; closes all of the tabs in the language hier-list.
        (define (close-all-languages)
          (define (close-children list)
            (for-each close-this-one (send list get-items)))
          (define (close-this-one item)
            (cond
              [(is-a? item hierarchical-list-compound-item<%>)
               (send item close)
               (close-children item)]
              [else (void)]))
          (close-children languages-hier-list))
        
        ;; open-current-language : -> void
        ;; opens the tabs that lead to the current language
        ;; and selects the current language
        (define (open-current-language)
          (cond
            [(not (and language-to-show settings-to-show))
             (no-language-selected)]
            [(is-a? language-to-show drracket:module-language:module-language<%>)
             (let ([hier-default (preferences:get 'drracket:language-dialog:hierlist-default)])
               (when hier-default
                 (select-a-language-in-hierlist hier-default)))
             ;; the above changes the radio button selections, so do it before calling module-language-selected
             (module-language-selected)]
            [else
             (send languages-hier-list focus) ;; only focus when the module language isn't selected
             (send use-chosen-language-rb set-selection 0)
             (send use-language-in-source-rb set-selection #f)
             (select-a-language-in-hierlist (send language-to-show get-language-position))]))
        
        (define (select-a-language-in-hierlist language-position)
          (cond
            [(null? (cdr language-position))
             ;; nothing to open here
             (send (car (send languages-hier-list get-items)) select #t)
             (void)]
            [else
             (let loop ([hi languages-hier-list]
                        
                        ;; skip the first position, since it is flattened into the dialog
                        [first-pos (cadr language-position)]
                        [position (cddr language-position)])
               (let ([matching-children
                      (filter (λ (x)
                                (equal? (send (send x get-editor) get-text)
                                        first-pos))
                              (send hi get-items))])
                 (cond
                   [(null? matching-children) 
                    ;; just give up here. probably this means that a bad preference was saved 
                    ;; and we're being called from the module-language case in 'open-current-language'
                    (void)]
                   [else
                    (let ([child (car matching-children)])
                      (cond
                        [(null? position)
                         (send child select #t)]
                        [else
                         (send child open)
                         (loop child (car position) (cdr position))]))])))]))
        
        ;; docs-callback : -> void
        (define (docs-callback)
          (void))
        
        ;; details-shown? : boolean
        ;; indicates if the details are currently visible in the dialog
        (define details-shown? (and language-to-show
                                    settings-to-show 
                                    (not (send language-to-show default-settings? settings-to-show))))
        
        ;; details-callback : -> void
        ;; flips the details-shown? flag and resets the GUI
        (define (details-callback)
          (do-construct-details)
          (set! details-shown? (not details-shown?))
          (when re-center
            (send re-center begin-container-sequence))
          (update-show/hide-details)
          (when re-center
            (send re-center center 'both)
            (send re-center end-container-sequence)))
        
        ;; do-construct-details : -> void
        ;; construct the details panels, if they have not been constructed
        (define (do-construct-details)
          (when construct-details
            (send details-button enable #f)
            (construct-details)
            (set! construct-details #f)
            (send details-button enable #t)))
        
        ;; show/hide-details : -> void
        ;; udpates the GUI based on the details-shown? flag
        (define (update-show/hide-details)
          (send details-button set-label 
                (if details-shown? hide-details-label show-details-label))
          (send parent begin-container-sequence)
          (send revert-to-defaults-outer-panel change-children
                (λ (l)
                  (if details-shown? (list revert-to-defaults-button) null)))
          (send details-outer-panel change-children
                (λ (l)
                  (if details-shown? (list details/manual-parent-panel) null)))
          (send parent end-container-sequence))
        
        ;; revert-to-defaults-callback : -> void
        (define (revert-to-defaults-callback)
          (when selected-language
            (get/set-selected-language-settings 
             (send selected-language default-settings))))
        
        (define show-details-label (string-constant show-details-button-label))
        (define hide-details-label (string-constant hide-details-button-label))
        (define details-button (make-object button% 
                                 (if (show-details-label . system-font-space->= . hide-details-label)
                                     show-details-label
                                     hide-details-label)
                                 show-details-parent
                                 (λ (x y)
                                   (details-callback))))
        
        (define revert-to-defaults-outer-panel (make-object horizontal-panel% show-details-parent))
        (define revert-to-defaults-button (make-object button% 
                                            (string-constant revert-to-language-defaults)
                                            revert-to-defaults-outer-panel
                                            (λ (_1 _2)
                                              (revert-to-defaults-callback))))
        
        (send revert-to-defaults-outer-panel stretchable-width #f)
        (send revert-to-defaults-outer-panel stretchable-height #f)
        (send outermost-panel set-alignment 'center 'center)
        
        (for-each add-language-to-dialog languages)
        (send languages-hier-list sort 
              (λ (x y)
                (cond
                  [(and (x . is-a? . second-number<%>)
                        (y . is-a? . second-number<%>))
                   (cond
                     [(= (send x get-second-number)
                         (send y get-second-number))
                      (< (send x get-number) (send y get-number))]
                     [else
                      (< (send x get-second-number)
                         (send y get-second-number))])]
                  [(and (x . is-a? . number<%>)
                        (y . is-a? . second-number<%>))
                   (cond
                     [(= (send x get-number)
                         (send y get-second-number))
                      #t]
                     [else
                      (< (send x get-number)
                         (send y get-second-number))])]
                  [(and (x . is-a? . second-number<%>)
                        (y . is-a? . number<%>))
                   (cond
                     [(= (send x get-second-number)
                         (send y get-number))
                      #f]
                     [else (< (send x get-second-number)
                              (send y get-number))])]
                  [(and (x . is-a? . number<%>)
                        (y . is-a? . number<%>))
                   (< (send x get-number) (send y get-number))]
                  [else #f])))
        
        ;; remove the newline at the front of the first inlined category (if there)
        ;; it won't be there if the module language is at the top.
        (let ([t (send (car (send languages-hier-list get-items)) get-editor)])
          (when (equal? "\n" (send t get-text 0 1))
            (send t delete 0 1)))
        
        (send details-outer-panel stretchable-width #f)
        (send details/manual-parent-panel change-children 
              (λ (l)
                (list details-panel)))
        
        (send languages-hier-list stretchable-width #t)
        (send languages-hier-list stretchable-height #t)
        (send languages-hier-list accept-tab-focus #t)
        (send languages-hier-list allow-tab-exit #t)
        (send parent reflow-container)
        (close-all-languages)
        (open-current-language)
        (send languages-hier-list min-client-width (text-width (send languages-hier-list get-editor)))
        (send languages-hier-list min-client-height (text-height (send languages-hier-list get-editor)))
        (when get/set-selected-language-settings
          (get/set-selected-language-settings settings-to-show))
        (when details-shown?
          (do-construct-details))
        (update-show/hide-details)
        (size-discussion-canvas in-source-discussion-editor-canvas)
        (values
         (λ () selected-language)
         (λ () 
           (and get/set-selected-language-settings
                (get/set-selected-language-settings)))
         (λ (receiver evt)
           (case (send evt get-key-code)
             [(#\u) 
              (if (mouse-event-uses-shortcut-prefix? evt)
                  (begin (send use-language-in-source-rb set-selection 0)
                         (use-language-in-source-rb-callback)
                         #t)
                  #f)]
             [(#\c)
              (if (mouse-event-uses-shortcut-prefix? evt)
                  (begin 
                    (send use-chosen-language-rb set-selection 0)
                    (use-chosen-language-rb-callback)
                    #t)
                  #f)]
             [else #f])))))
    
    (define (add-discussion p)
      (let* ([t (new text:standard-style-list%)]
             [c (new editor-canvas%
                     [stretchable-width #t]
                     [horizontal-inset 0]
                     [vertical-inset 0]
                     [parent p]
                     [style '(no-border no-vscroll no-hscroll transparent)]
                     [editor t])])
        (send t set-styles-sticky #f)
        (send t set-autowrap-bitmap #f)
        (let* ([size-sd (make-object style-delta% 'change-size (send normal-control-font get-point-size))]
               [do-insert
                (λ (str tt-style?)
                  (let ([before (send t last-position)])
                    (send t insert str before before)
                    (cond
                      [tt-style?
                       (send t change-style 
                             (send (send t get-style-list) find-named-style "Standard")
                             before (send t last-position))]
                      [else
                       (send t change-style 
                             (send (send t get-style-list) basic-style)
                             before (send t last-position))])
                    (send t change-style size-sd before (send t last-position))))])
          (let loop ([strs (regexp-split #rx"#lang" sc-lang-in-source-discussion)])
            (do-insert (car strs) #f)
            (unless (null? (cdr strs))
              (do-insert "#lang" #t)
              (loop (cdr strs)))))
        (send t hide-caret #t)
        
        (send t auto-wrap #t)
        (send t lock #t)
        (send c accept-tab-focus #f)
        (send c allow-tab-exit #t)
        c))
    
    (define (size-discussion-canvas canvas)
      (let ([t (send canvas get-editor)])
        
        (let ([by (box 0)])
          (send t position-location 
                (send t line-end-position (send t last-line))
                #f
                by)
          (send canvas min-height (+ (ceiling (inexact->exact (unbox by))) 24)))))
    
    (define section-style-delta (make-object style-delta% 'change-bold))
    (send section-style-delta set-delta-foreground "medium blue")
    (define small-size-delta (make-object style-delta% 'change-size 9))
    
    (define (add-welcome dialog welcome-before-panel welcome-after-panel)
      (let* ([outer-pb%
              (class pasteboard%
                (define/override (can-interactive-move? evt)
                  #f)
                (super-instantiate ()))]
             [outer-pb (make-object outer-pb%)]
             [bitmap 
              (make-object bitmap%
                (build-path (collection-file-path "plt-small-shield.gif" "icons")))]
             [image-snip
              (make-object image-snip% 
                (collection-file-path "plt-small-shield.gif" "icons"))]
             [before-text (make-object text%)]
             [before-snip (make-object editor-snip% before-text #f)]
             [before-ec%
              (class editor-canvas% 
                (inherit get-client-size)
                (define/private (update-size)
                  (let-values ([(cw ch) (get-client-size)])
                    (unless (or (zero? cw)
                                (zero? ch))
                      (let ([image-l-box (box 0)]
                            [image-r-box (box 0)])
                        (send before-text get-snip-location image-snip image-l-box #f #f)
                        (send before-text get-snip-location image-snip image-r-box #f #t)
                        (let* ([image-w (send bitmap get-width)]
                               [before-snip-space (- cw image-w)]
                               [before-snip-w (- before-snip-space
                                                 5 5 ;; space before and after inside snip 
                                                 2   ;; space at end of outer editor
                                                 1   ;; space at beginning of outer editor
                                                 1   ;; space between image and snip
                                                 -5  ;; unknown space
                                                 )])
                          (send before-text set-max-width (max 0 before-snip-w)))))))
                (define/override (on-superwindow-show shown?)
                  (update-size)
                  (super on-superwindow-show shown?))
                (define/override (on-size w h)
                  (update-size)
                  (super on-size w h))
                (super-instantiate ()))]
             [before-ec (instantiate before-ec% ()
                          (parent welcome-before-panel)
                          (editor outer-pb)
                          (stretchable-height #f)
                          (style '(no-vscroll no-hscroll)))]
             [first-line-style-delta (make-object style-delta% 'change-bold)])
        (send first-line-style-delta set-delta-foreground (make-object color% 150 0 150))
        (send before-ec min-width 550)
        
        (let-values ([(cw ch) (send before-ec get-client-size)]
                     [(w h) (send before-ec get-size)])
          (send before-ec min-height 
                (+ (send bitmap get-height) 
                   8  ;; pasteboards apparently want some space here....
                   (- h ch))))
        
        (send outer-pb insert image-snip)
        (send outer-pb insert before-snip)
        (send outer-pb move image-snip 0 0)
        (send outer-pb move before-snip (send bitmap get-width) 0)
        (send outer-pb set-selection-visible #f)
        (send outer-pb lock #t)
        
        ;(send before-snip set-align-top-line #t)
        (send before-text insert 
              (format (string-constant welcome-to-drscheme-version/language)
                      (version:version)
                      (this-language)))
        (send before-text insert #\newline)
        (send before-text insert (string-constant introduction-to-language-dialog))
        (send before-text change-style 
              first-line-style-delta
              0
              (send before-text paragraph-end-position 0))
        (send before-text auto-wrap #t)
        
        (send before-text lock #t)
        (send before-text hide-caret #t)
        
        (for-each (λ (native-lang-string language)
                    (unless (equal? (this-language) language)
                      (instantiate button% ()
                        (label native-lang-string)
                        (parent welcome-after-panel)
                        (stretchable-width #t)
                        (callback (λ (x1 x2) (drracket:app:switch-language-to dialog language))))))
                  (string-constants is-this-your-native-language)
                  (all-languages))))
    
    ;; system-font-space->= : string string -> boolean
    ;; determines which string is wider, when drawn in the system font
    (define (x . system-font-space->= . y)
      (let ([bdc (make-object bitmap-dc%)])
        (send bdc set-bitmap (make-object bitmap% 1 1 #t))
        (send bdc set-font (send the-font-list find-or-create-font
                                 12 'system 'normal 'normal))
        (let-values ([(wx _1 _2 _3) (send bdc get-text-extent x)]
                     [(wy _4 _5 _6) (send bdc get-text-extent y)])
          (wx . >= . wy))))
    
    ;; text-width : (isntanceof text%) -> exact-integer
    ;; calculates the width of widest line in the
    ;; editor. This only makes sense if auto-wrap
    ;; is turned off. Otherwise, you could just use
    ;; the admin's width.
    (define (text-width text)
      (let loop ([n (+ (send text last-line) 1)]
                 [current-max-width 0])
        (cond
          [(zero? n)
           (+
            10 ;; this should be some magic small constant (hopefully less than 10 on all platforms)
            (floor (inexact->exact current-max-width)))]
          [else (let* ([line-number (- n 1)]
                       [box (box 0.0)]
                       [eol-pos (send text line-end-position line-number)]
                       [eol-snip (send text find-snip eol-pos 'before)])
                  (when eol-snip
                    (send text get-snip-location eol-snip box #f #t))
                  (loop (- n 1)
                        (max current-max-width (unbox box))))])))
    
    ;; text-height : (is-a?/c text% -> exact-integer
    (define (text-height text)
      (let ([y-box (box 0)])
        (send text position-location 
              (send text last-position)
              #f
              y-box
              #f
              #f
              #t)
        (+ 10 ;; upper bound on some platform specific space I don't know how to get.
           (floor (inexact->exact (unbox y-box))))))
    

;                                                   
;                                                   
;     ;             ;;;                             
;                  ;                                
;   ;;;   ;; ;;   ;;;;;   ;;;           ;;;;   ;;;; 
;     ;    ;;  ;   ;     ;   ;         ;   ;  ;   ; 
;     ;    ;   ;   ;     ;   ;          ;;;    ;;;  
;     ;    ;   ;   ;     ;   ;             ;      ; 
;     ;    ;   ;   ;     ;   ;   ;;    ;   ;  ;   ; 
;   ;;;;; ;;; ;;; ;;;;;   ;;;    ;;    ;;;;   ;;;;  
;                                                   
;                                                   
;                                                   
;                                                   
;                                                                 
;                                                                 
;    ;;                                                           
;     ;                                                           
;     ;     ;;;  ;; ;;    ;; ;;;;  ;;   ;;;    ;; ;;  ;;;    ;;;; 
;     ;    ;   ;  ;;  ;  ;  ;;  ;   ;  ;   ;  ;  ;;  ;   ;  ;   ; 
;     ;     ;;;;  ;   ;  ;   ;  ;   ;   ;;;;  ;   ;  ;;;;;   ;;;  
;     ;    ;   ;  ;   ;  ;   ;  ;   ;  ;   ;  ;   ;  ;          ; 
;     ;    ;   ;  ;   ;  ;   ;  ;  ;;  ;   ;  ;   ;  ;      ;   ; 
;   ;;;;;   ;;;;;;;; ;;;  ;;;;   ;; ;;  ;;;;;  ;;;;   ;;;;  ;;;;  
;                            ;                    ;               
;                         ;;;                  ;;;                
;                                                                 
;                                                                 
    
    (define (add-info-specified-languages)
      (for-each add-info-specified-language
                (find-relevant-directories '(drscheme-language-positions))))
    
    (define (add-info-specified-language directory)
      (let ([info-proc (get-info/full directory)])
        (when info-proc
          (let* ([lang-positions (info-proc 'drscheme-language-positions (λ () null))]
                 [lang-modules (info-proc 'drscheme-language-modules (λ () null))]
                 [numberss (info-proc 'drscheme-language-numbers 
                                      (λ ()
                                        (map (λ (lang-position)
                                               (map (λ (x) 0) lang-position))
                                             lang-positions)))]
                 [summaries (info-proc 'drscheme-language-one-line-summaries 
                                       (λ ()
                                         (map (λ (lang-position) "")
                                              lang-positions)))]
                 [urls      (info-proc 'drscheme-language-urls 
                                       (λ ()
                                         (map (λ (lang-position) "")
                                              lang-positions)))]
                 [reader-specs
                  (info-proc 'drscheme-language-readers
                             (λ ()
                               (map (λ (lang-position) #f)
                                    lang-positions)))])
            (cond
              [(and (list? lang-positions)
                    (andmap (λ (lang-position numbers)
                              (and (list? lang-position)
                                   (pair? lang-position)
                                   (andmap string? lang-position)
                                   (list? numbers)
                                   (andmap number? numbers)
                                   (= (length numbers)
                                      (length lang-position))))
                            lang-positions
                            numberss)
                    (list? lang-modules)
                    (andmap (λ (x)
                              (or (string? x)
                                  (and (list? x)
                                       (andmap string? x))))
                            lang-modules)
                    (list? summaries)
                    (andmap string? summaries)
                    
                    (list? urls)
                    (andmap string? urls)
                    
                    (list? reader-specs)
                    (andmap (λ (x)
                              ;; approximation (no good test, really)
                              ;; since it depends on the value of a mz
                              ;; parameter to interpret the module spec
                              (or (string? x) (eq? x #f) (symbol? x) (pair? x)))
                            reader-specs)
                    
                    (= (length lang-positions)
                       (length lang-modules)
                       (length summaries)
                       (length urls)
                       (length reader-specs)))
               (for-each
                (λ (lang-module lang-position lang-numbers one-line-summary url reader-spec)
                  (let ([%
                         ((drracket:language:get-default-mixin)
                          (drracket:language:module-based-language->language-mixin
                           (drracket:language:simple-module-based-language->module-based-language-mixin
                            drracket:language:simple-module-based-language%)))]
                        [reader
                         (if reader-spec
                             (with-handlers ([exn:fail?
                                              (λ (x)
                                                (message-box (string-constant drscheme)
                                                             (if (exn? x)
                                                                 (exn-message x)
                                                                 (format "uncaught exception: ~s" x)))
                                                read-syntax/namespace-introduce)])
                               (contract
                                (->* ()
                                     (any/c port?)
                                     (or/c syntax? eof-object?))
                                (dynamic-require
                                 (cond
                                   [(string? reader-spec)
                                    (build-path
                                     directory 
                                     (platform-independent-string->path reader-spec))]
                                   [else reader-spec])
                                 'read-syntax)
                                (string->symbol (format "~s" lang-position))
                                'drscheme))
                             read-syntax/namespace-introduce)])
                    (add-language (instantiate % ()
                                    (module (if (string? lang-module)
                                                (build-path
                                                 directory 
                                                 (platform-independent-string->path lang-module))
                                                `(lib ,@lang-module)))
                                    (language-position lang-position)
                                    (language-id (format "plt:lang-from-module: ~s" lang-module))
                                    (language-numbers lang-numbers)
                                    (one-line-summary one-line-summary)
                                    (language-url url)
                                    (reader reader)))))
                lang-modules
                lang-positions
                numberss
                summaries
                urls
                reader-specs)]
              [else
               (message-box
                (string-constant drscheme)
                (format
                 (string-append
                  "The drscheme-language-position, drscheme-language-modules, drscheme-language-numbers,"
                  " and drscheme-language-readers specifications aren't correct. Expected"
                  " (listof (cons string (listof string))), (listof (listof string)), (listof (listof number)), (listof string),"
                  " (listof string), and (listof module-spec) respectively, where the lengths of the outer lists are the same."
                  " Got ~e, ~e, ~e, ~e, ~e, and ~e")
                 lang-positions
                 lang-modules
                 numberss
                 summaries
                 urls
                 reader-specs))])))))
    
    (define (platform-independent-string->path str)
      (apply
       build-path
       (map (λ (x) 
              (cond
                [(string=? ".." x) 'up]
                [(string=? "." x) 'same]
                [else x]))
            (regexp-split #rx"/" str))))
    
    (define read-syntax/namespace-introduce
      (λ (source-name-v [input-port (current-input-port)])
        (let ([v (read-syntax source-name-v input-port)])
          (if (syntax? v)
              (namespace-syntax-introduce v)
              v))))
    
    

;                                                          
;                                                          
;  ;;               ;     ;;                    ;          
;   ;                      ;     ;                         
;   ; ;;  ;;  ;;  ;;;      ;    ;;;;;         ;;;   ;; ;;  
;   ;;  ;  ;   ;    ;      ;     ;              ;    ;;  ; 
;   ;   ;  ;   ;    ;      ;     ;     ;;;;;    ;    ;   ; 
;   ;   ;  ;   ;    ;      ;     ;              ;    ;   ; 
;   ;   ;  ;  ;;    ;      ;     ;   ;          ;    ;   ; 
;  ;;;;;    ;; ;; ;;;;;  ;;;;;    ;;;         ;;;;; ;;; ;;;
;                                                          
;                                                          
;                                                          
;                                                          
;                                                                 
;                                                                 
;    ;;                                                           
;     ;                                                           
;     ;     ;;;  ;; ;;    ;; ;;;;  ;;   ;;;    ;; ;;  ;;;    ;;;; 
;     ;    ;   ;  ;;  ;  ;  ;;  ;   ;  ;   ;  ;  ;;  ;   ;  ;   ; 
;     ;     ;;;;  ;   ;  ;   ;  ;   ;   ;;;;  ;   ;  ;;;;;   ;;;  
;     ;    ;   ;  ;   ;  ;   ;  ;   ;  ;   ;  ;   ;  ;          ; 
;     ;    ;   ;  ;   ;  ;   ;  ;  ;;  ;   ;  ;   ;  ;      ;   ; 
;   ;;;;;   ;;;;;;;; ;;;  ;;;;   ;; ;;  ;;;;;  ;;;;   ;;;;  ;;;;  
;                            ;                    ;               
;                         ;;;                  ;;;                
;                                                                 
;                                                                 
   
    
    ;; add-expand-to-front-end : mixin
    ;; overrides front-end to make the language a language that expands its arguments
    (define (add-expand-to-front-end %)
      (class %
        (define/override (front-end/complete-program input settings)
          (wrap-front-end (super front-end/complete-program input settings)))
        (define/override (front-end/interaction input settings)
          (wrap-front-end (super front-end/interaction input settings)))
        (define/private (wrap-front-end thnk)
          (λ ()
            (let ([res (thnk)])
              (cond
                [(syntax? res) (with-syntax ([res res]
                                             [expand-syntax-top-level-with-compile-time-evals
                                              expand-syntax-top-level-with-compile-time-evals])
                                 #'(expand-syntax-top-level-with-compile-time-evals
                                    (quote-syntax res)))]
                [(eof-object? res) res]
                [else `(expand ',res)]))))
        (super-instantiate ())))
    
    (define-struct (simple-settings+assume drracket:language:simple-settings) (no-redef?))
    (define simple-settings+assume->vector (make-->vector simple-settings+assume))

    (define (macro-stepper-mixin %)
      (class %
        (super-new)
        (define/augment (capability-value key)
          (cond
            [(eq? key 'macro-stepper:enabled) #t]
            [else (inner (drracket:language:get-capability-default key)
                         capability-value key)]))))

    (define (assume-mixin %)
      (class %
        (define/override (default-settings) 
          (extend-simple-settings (super default-settings) #t))

        (define/override (marshall-settings settings)
          (simple-settings+assume->vector settings))

        (define/override (unmarshall-settings printable)
          (and (vector? printable)
               (= (vector-length printable) 7)
               (let ([base
                      (super unmarshall-settings
                             (list->vector
                              (reverse
                               (cdr (reverse (vector->list printable))))))])
                 (and base
                      (extend-simple-settings
                       base
                       (and (vector-ref printable 6) #t))))))

        (define/override (config-panel parent)
          (let ([p (new vertical-panel% [parent parent])])
            (let ([base-config (super config-panel p)]
                  [assume-cb (new check-box%
                                  [parent 
                                   (new group-box-panel%
                                        [parent p]
                                        [label (string-constant enforce-primitives-group-box-label)]
                                        [stretchable-height #f]
                                        [stretchable-width #f])]
                                  [label (string-constant enforce-primitives-check-box-label)])])
              (case-lambda
               [() (extend-simple-settings (base-config)
                                           (send assume-cb get-value))]
               [(c)
                (base-config c)
                (send assume-cb set-value (simple-settings+assume-no-redef? c))]))))

        (define/override (default-settings? x)
          (equal? (simple-settings+assume->vector x)
                  (simple-settings+assume->vector (default-settings))))

        (define/private (extend-simple-settings s no-redef?)
          (make-simple-settings+assume (drracket:language:simple-settings-case-sensitive s)
                                       (drracket:language:simple-settings-printing-style s)
                                       (drracket:language:simple-settings-fraction-style s)
                                       (drracket:language:simple-settings-show-sharing s)
                                       (drracket:language:simple-settings-insert-newlines s)
                                       (drracket:language:simple-settings-annotations s)
                                       no-redef?))

        (define/override (use-namespace-require/copy-from-setting? s)
          (not (simple-settings+assume-no-redef? s)))

        (super-new)))

    (define (add-errortrace-key-mixin %)
      (class %
        (define/override (on-execute setting run-in-user-thread)
          (super on-execute setting run-in-user-thread)
          (run-in-user-thread
           (λ ()
             (namespace-require 'errortrace/errortrace-key)
             (namespace-require '(for-syntax errortrace/errortrace-key)))))
        (super-new)))
  
    (define (r5rs-mixin %)
      (class %
        (define/override (on-execute setting run-in-user-thread)
          (super on-execute setting run-in-user-thread)
          (run-in-user-thread
           (λ ()
             (read-square-bracket-as-paren #f)
             (read-curly-brace-as-paren #f)
             (read-accept-infix-dot #f)
             (print-mpair-curly-braces #f)
             (print-vector-length #f))))
        (define/override (get-transformer-module) #f)

        (define/override (default-settings) 
          (make-simple-settings+assume #f 'trad-write 'mixed-fraction-e #f #t 'debug #t))

        (super-new)))
  
    (define (pretty-big-mixin %)
      (class %
        ;; since check syntax no longer shares the gui libraries, 
        ;; we always share it explicitly here
        (define/override (on-execute setting run-in-user-thread)
          (let ([mred-name ((current-module-name-resolver) 'mred/mred #f #f)])
            (run-in-user-thread
             (λ ()
               (namespace-attach-module drracket:init:system-namespace mred-name))))
          (super on-execute setting run-in-user-thread))
        (define/override (default-settings) 
          (let ([s (super default-settings)])
            (make-simple-settings+assume (drracket:language:simple-settings-case-sensitive s)
                                         'trad-write
                                         (drracket:language:simple-settings-fraction-style s)
                                         (drracket:language:simple-settings-show-sharing s)
                                         (drracket:language:simple-settings-insert-newlines s)
                                         (drracket:language:simple-settings-annotations s)
                                         (simple-settings+assume-no-redef? s))))
        (super-new)))
    
    (define get-all-scheme-manual-keywords
      (let ([words #f])
        (λ ()
          (unless words
            (set! words (text:get-completions/manuals '(racket/base racket/contract))))
          words)))
    
    (define get-all-manual-keywords
      (let ([words #f])
        (λ ()
          (unless words
            (set! words (text:get-completions/manuals #f)))
          words)))
    
    ;; add-built-in-languages : -> void
    (define (add-built-in-languages)
      (let* ([words #f]
             [extras-mixin
              (λ (mred-launcher? one-line-summary)
                (λ (%)
                  (class* % (drracket:language:language<%>)
                    (define/override (get-one-line-summary) one-line-summary)
                    (inherit get-module get-transformer-module get-init-code
                             use-namespace-require/copy-from-setting?)
                    (define/override (front-end/interaction port settings)
                      (let ([t (super front-end/interaction port settings)])
                        (λ ()
                          (parameterize ([read-accept-lang #f])
                            (t)))))
                    (define/augment (capability-value key)
                      (cond
                        [(eq? key 'drscheme:autocomplete-words) 
                         (get-all-manual-keywords)]
                        [else (inner
                               (drracket:language:get-capability-default key)
                               capability-value key)]))
                    (define/override (create-executable setting parent program-filename)
                      (let ([executable-fn
                             (drracket:language:put-executable
                              parent
                              program-filename
                              #t
                              mred-launcher?
                              (if mred-launcher?
                                  (string-constant save-a-mred-launcher)
                                  (string-constant save-a-mzscheme-launcher)))])
                        (when executable-fn
                          (drracket:language:create-module-based-launcher
                           program-filename
                           executable-fn
                           (get-module)
                           (get-transformer-module)
                           (get-init-code setting)
                           mred-launcher?
                           (use-namespace-require/copy-from-setting? setting)))))
                    (super-new))))]
             [make-simple
              (λ (module id position numbers mred-launcher? one-line-summary extra-mixin)
                (let ([%
                       (extra-mixin
                        ((extras-mixin mred-launcher? one-line-summary)
                         ((drracket:language:get-default-mixin)
                          (drracket:language:module-based-language->language-mixin
                           (drracket:language:simple-module-based-language->module-based-language-mixin
                            drracket:language:simple-module-based-language%)))))])
                  (instantiate % ()
                    (module module)
                    (language-id id)
                    (language-position position)
                    (language-numbers numbers))))])
        (add-language
         (make-simple '(lib "lang/plt-pretty-big.rkt")
                      "plt:pretty-big"
                      (list (string-constant legacy-languages)
                            (string-constant pretty-big-scheme))
                      (list -200 3)
                      #t
                      (string-constant pretty-big-scheme-one-line-summary)
                      (λ (%) (pretty-big-mixin (macro-stepper-mixin (assume-mixin (add-errortrace-key-mixin %)))))))
        (add-language
         (make-simple '(lib "r5rs/lang.rkt")
                      "plt:r5rs"
                      (list (string-constant legacy-languages)
                            (string-constant r5rs-language-name))
                      (list -200 -1000)
                      #f
                      (string-constant r5rs-one-line-summary)
                      (lambda (%) (r5rs-mixin (macro-stepper-mixin (assume-mixin (add-errortrace-key-mixin %)))))))
        
        (add-language
         (make-simple 'racket/base
                      "plt:no-language-chosen"
                      (list (string-constant initial-language-category)
                            (string-constant no-language-chosen))
                      (list 10000 1000)
                      #f
                      "Helps the user choose an initial language"
                      not-a-language-extra-mixin))))
    
    (define (not-a-language-extra-mixin %)
      (class* % (not-a-language-language<%>)
        (define/override (get-style-delta) drracket:rep:error-delta)
        
        (define/override (first-opened) 
          (not-a-language-message)
          (fprintf (current-error-port) "\n"))
        
        (define/override (front-end/interaction input settings)
          (not-a-language-message)
          (λ () eof))
        (define/override (front-end/complete-program input settings)
          (not-a-language-message)
          (λ () eof))
        
        (define/augment (capability-value v)
          (case v
            [(drscheme:define-popup) #f]
            [(gui-debugger:debug-button) #f]
            [(macro-stepper:enabled) #f]
            [(drscheme:check-syntax-button) #f]
            [else (inner (drracket:language:get-capability-default v)
                         capability-value v)]))
        
        (super-new)))
    
    ;; used for identification only
    (define not-a-language-language<%>
      (interface ()))
    
    

;                                                                                                    
;                                                                                                    
;                                              ;;                                                    
;                  ;                            ;                                                    
;  ;; ;;    ;;;   ;;;;;          ;;;            ;     ;;;  ;; ;;    ;; ;;;;  ;;   ;;;    ;; ;;  ;;;  
;   ;;  ;  ;   ;   ;            ;   ;           ;    ;   ;  ;;  ;  ;  ;;  ;   ;  ;   ;  ;  ;;  ;   ; 
;   ;   ;  ;   ;   ;     ;;;;;   ;;;;  ;;;;;    ;     ;;;;  ;   ;  ;   ;  ;   ;   ;;;;  ;   ;  ;;;;; 
;   ;   ;  ;   ;   ;            ;   ;           ;    ;   ;  ;   ;  ;   ;  ;   ;  ;   ;  ;   ;  ;     
;   ;   ;  ;   ;   ;   ;        ;   ;           ;    ;   ;  ;   ;  ;   ;  ;  ;;  ;   ;  ;   ;  ;     
;  ;;; ;;;  ;;;     ;;;          ;;;;;        ;;;;;   ;;;;;;;; ;;;  ;;;;   ;; ;;  ;;;;;  ;;;;   ;;;; 
;                                                                      ;                    ;        
;                                                                   ;;;                  ;;;         
;                                                                                                    
;                                                                                                    
    
    
    (define (not-a-language-message)
      (define (main)
        (when (language-still-unchanged?)
          (o (green-snip (string-constant must-choose-language)))
          (o "\n")
          (o (green-snip (string-constant get-guidance-before)))
          (o (new link-snip%
                  [words (string-constant get-guidance-during)]
                  [callback (lambda (snip)
                              (not-a-language-dialog (find-parent-from-snip snip)))]))
          (o (green-snip (string-constant get-guidance-after)))))
      
      (define (green-snip str)
        (let ([snp (make-object string-snip% str)])
          (send snp set-style green-style)
          snp))
      
      (define green-style
        (let ([list (editor:get-standard-style-list)]
              [green-style-delta (make-object style-delta% 'change-family 'default)])
          (send green-style-delta set-delta-foreground "DarkViolet")
          (send green-style-delta set-delta 'change-italic)
          (send list
                find-or-create-style
                (send list find-named-style "Standard")
                green-style-delta)))
      
      (define (language-still-unchanged?)
        (let ([rep (drracket:rep:current-rep)])
          (cond
            [rep 
             (let* ([next-settings (send (send rep get-definitions-text) get-next-settings)]
                    [next-lang (language-settings-language next-settings)])
               (is-a? next-lang not-a-language-language<%>))]
            
            ;; if we cannot get the REP
            ;; (because a tool is processing the progrm like check syntax)
            ;; then just assume it has not changed.
            [else #t])))
      
      (define o
        (case-lambda
          [(arg)
           (cond
             [(string? arg)
              (fprintf (current-error-port) arg)]
             [(is-a? arg snip%)
              (write-special arg (current-error-port))])]
          [args (apply fprintf (current-error-port) args)]))
      
      (define arrow-cursor (make-object cursor% 'arrow))
      
      (define link-snip%
        (class editor-snip%
          (init-field words callback)
          
          (define/override (adjust-cursor dc x y editorx editory event) arrow-cursor)
          
          (define/override (on-event dc x y editorx editory event)
            (when (send event button-up?)
              (callback this)))
          
          (define/override (copy)
            (new link-snip% [words words] [callback callback]))
          
          (define txt (new text:standard-style-list%))
          
          (super-new [editor txt] [with-border? #f]
                     [left-margin 0]
                     [right-margin 0]
                     [top-margin 0]
                     [bottom-margin 0])
          (inherit get-flags set-flags set-style)
          (set-flags (cons 'handles-events (get-flags)))
          
          (send txt insert words)
          (send txt change-style link-sd 0 (send txt last-position))))
      
      (define link-sd (make-object style-delta% 'change-underline #t))
      (define stupid-internal-define-syntax1
        (begin (send link-sd set-delta-foreground "blue")
               (send link-sd set-family 'default)))
      
      (main))
    
    (define (not-a-language-dialog drs-frame)
      (define dialog (new dialog%
                          (parent drs-frame)
                          (label (string-constant drscheme))))
      (define top-hp (new horizontal-pane% [parent dialog]))
      (define qa-panel (new vertical-panel% [style '(border)] (parent top-hp) (stretchable-width #f)))
      (define racketeer-panel (new vertical-panel% [style '(border)] [parent top-hp] [alignment '(center center)] [stretchable-width #f]))
      (define button-panel (new horizontal-pane% 
                                (parent dialog) 
                                (stretchable-height #f)
                                (alignment '(right center))))
      
      (define cancel (new button%
                          (parent button-panel)
                          (callback (lambda (x y) (send dialog show #f)))
                          (label (string-constant cancel))))
      
      (define language-chosen? #f)
      
      (define (main)
        (insert-text-pls)
        (display-racketeer)
        (space-em-out)
        (fix-msg-sizes)
        (send dialog show #t))
      
      (define (insert-red-message)
        (new canvas-message% 
             (parent qa-panel)
             (font (get-font #:style 'italic))
             (label (string-constant must-choose-language))
             (color (send the-color-database find-color "red"))))
      
      (define (space-em-out)
        (send qa-panel change-children
              (lambda (l)
                (cond
                  [(null? l) l]
                  [else
                   (let loop ([x (car l)]
                              [r (cdr l)])
                     (cond
                       [(null? r) (list x)]
                       [else (list* x
                                    (new vertical-pane%
                                         (parent qa-panel)
                                         (min-height 5)
                                         (stretchable-height #f))
                                    (loop (car r)
                                          (cdr r)))]))]))))
      
      (define (insert-text-pls)
        (for-each
         display-text-pl
         (sort
          (apply append (map get-text-pls (find-relevant-directories '(textbook-pls))))
          (λ (x y)
            (cond
              [(string=? (cadr x) (string-constant how-to-design-programs))
               #t]
              [(string=? (string-constant how-to-design-programs) (cadr y))
               #f]
              [else
               (string<=? (cadr x) (cadr y))])))))
      
      (define plt-logo-shiny
        (make-object bitmap% (collection-file-path "plt-logo-red-shiny.png" "icons")
          'png/mask))

      (define (display-racketeer)
        (new canvas-message% 
             (parent racketeer-panel)
             (label (string-constant racketeer?)))
        (new canvas% 
             [parent racketeer-panel]
             [stretchable-width #f]
             [paint-callback
              (λ (c dc)
                (send dc set-scale 1/2 1/2)
                (send dc draw-bitmap plt-logo-shiny 0 0
                      'solid (send the-color-database find-color "black")
                      (send plt-logo-shiny get-loaded-mask)))]
             [style '(transparent)]
             [min-width (floor (/ (send plt-logo-shiny get-width) 2))]
             [min-height (floor (/ (send plt-logo-shiny get-height) 2))])
        (new canvas-message%
             (parent racketeer-panel) 
             (label (string-constant use-language-in-source))
             (color (send the-color-database find-color "blue"))
             (callback (λ () (change-current-lang-to (λ (x) (is-a? x drracket:module-language:module-language<%>)))))
             (font (get-font #:underlined #t))))
      
      (define (display-text-pl lst)
        (let ([icon-lst (car lst)]
              [text-name (cadr lst)]
              [lang (cddr lst)]
              [using-before (string-constant using-a-textbook-before)]
              [using-after (string-constant using-a-textbook-after)])
          (question/answer (lambda (parent)
                             (new canvas-message%
                                  (parent parent)
                                  (label using-before))
                             (new canvas-message%
                                  (parent parent)
                                  (font (get-font #:style 'italic))
                                  (label text-name))
                             (new canvas-message%
                                  (parent parent)
                                  (label using-after)))
                           (default-line2 (last lang) lang)
                           icon-lst)))
      
      (define default-font (send the-font-list find-or-create-font
                                 12
                                 'default
                                 'normal
                                 'normal))
      
      (define (get-font #:point-size [point-size (send default-font get-point-size)]
                        #:family (family (send default-font get-family))
                        #:style (style (send default-font get-style))
                        #:weight (weight (send default-font get-weight))
                        #:underlined (underlined (send default-font get-underlined))
                        #:smoothing (smoothing (send default-font get-smoothing)))
        (send the-font-list find-or-create-font
              point-size
              family
              style
              weight
              underlined
              smoothing))
      
      (define canvas-message%
        (class canvas%
          (init-field label
                      [font (get-font)]
                      [callback void]
                      [color (send the-color-database find-color "black")])
          
          (define/override (on-event evt)
            (cond
              [(send evt button-up?)
               (callback)]
              [else 
               (super on-event evt)]))
          
          (define/override (on-paint)
            (let* ([dc (get-dc)]
                   [old-font (send dc get-font)]
                   [old-tf (send dc get-text-foreground)])
              (send dc set-text-foreground color)
              (send dc set-font font)
              (send dc draw-text label 0 0 #t)
              (send dc set-font old-font)
              (send dc set-text-foreground old-tf)))
          
          (super-new [stretchable-width #f]
                     [stretchable-height #f]
                     [style '(transparent)])
          
          (inherit min-width min-height get-dc)
          (let-values ([(w h _1 _2) (send (get-dc) get-text-extent label font #t)])
            (min-width (inexact->exact (floor w)))
            (min-height (inexact->exact (floor h))))))
      
      (define (question/answer line1 line2 icon-lst)
        (display-two-line-choice 
         icon-lst
         (λ (panel1 panel2)
           (line1 panel1)
           (line2 panel2))))
      
      (define ((default-line2 lang-name lang) panel2)
        (new canvas-message% (parent panel2) (label (string-constant start-with-before)))
        (new canvas-message%
             (parent panel2) 
             (label lang-name)
             (color (send the-color-database find-color "blue"))
             (callback (λ () (change-current-lang-to lang)))
             (font (get-font #:underlined #t)))
        (new canvas-message% (parent panel2) (label (string-constant start-with-after))))
      
      ;; get-text-pls : path -> (listof (list* string string (listof string))
      ;; gets the questions from an info.rkt file.
      (define (get-text-pls info-filename)
        (let ([proc (get-info/full info-filename)])
          (if proc
              (let ([qs (proc 'textbook-pls)])
                (unless (list? qs)
                  (error 'splash-questions "expected a list, got ~e" qs))
                (for-each 
                 (lambda (pr)
                   (unless (and (pair? pr)
                                (pair? (cdr pr))
                                (pair? (cddr pr))
                                (list? (cdddr pr))
                                (let ([icon-lst (car pr)])
                                  (and (list? icon-lst)
                                       (not (null? icon-lst))
                                       (andmap string? icon-lst)))
                                (andmap string? (cdr pr)))
                     (error 
                      'splash-questions
                      "expected a list of lists, with each inner list being at least three elements long and the first element of the inner list being a list of strings and the rest of the elements being strings, got ~e"
                      pr)))
                 qs)
                qs)
              '())))
      
      (define msgs '())
      (define (fix-msg-sizes)
        (let ([w (apply max (map (λ (x) (send x get-width)) msgs))])
          (for-each (λ (b) (send b min-width w))
                    msgs)))
      
      (define (display-two-line-choice icon-lst proc)
        (let* ([hp (new horizontal-pane% 
                        (parent qa-panel)
                        (alignment '(center top))
                        (stretchable-height #f))]
               [msg (new message%
                         (label (make-object bitmap%
                                  (apply collection-file-path icon-lst)
                                  'unknown/mask))
                         (parent hp))]
               [vp (new vertical-pane% 
                        (parent hp)
                        (alignment '(left top))
                        (stretchable-height #f))])
          (set! msgs (cons msg msgs))
          (proc (new horizontal-pane% (parent vp))
                (new horizontal-pane% (parent vp)))))
      
      ;; change-current-lang-to : (or/c (-> any/c boolean?) (listof string)) -> void
      ;; closed the guidance dialog and opens the language dialog
      (define (change-current-lang-to lang-strings/predicate)
        (send dialog show #f)
        (let* ([predicate (if (procedure? lang-strings/predicate)
                              lang-strings/predicate
                              (λ (x) (equal? lang-strings/predicate (send x get-language-position))))]
               [lang (ormap (λ (x) (and (predicate x) x))
                            (get-languages))])
          (unless lang
            (error 'change-current-lang-to "unknown language! ~s" lang-strings/predicate))
          
          (let ([new-lang
                 (language-dialog #f
                                  (language-settings lang
                                                     (send lang default-settings))
                                  drs-frame)])
            (when new-lang
              (set! language-chosen? #t)
              (preferences:set settings-preferences-symbol new-lang)
              (send (send drs-frame get-definitions-text) set-next-settings new-lang)))))
      
      (main))
    
    ;; find-parent-from-editor : editor -> (union frame #f)
    (define (find-parent-from-editor ed)
      (cond
        [(send ed get-canvas)
         =>
         (λ (c) (send c get-top-level-window))]
        [else
         (let ([admin (send ed get-admin)])
           (and (is-a? admin editor-snip-editor-admin<%>)
                (find-parent-from-snip (send admin get-snip))))]))
    
    ;; find-parent-from-snip : snip -> (union frame #f)
    (define (find-parent-from-snip snip)
      (let* ([admin (send snip get-admin)]
             [ed (send admin get-editor)])
        (find-parent-from-editor ed))))
