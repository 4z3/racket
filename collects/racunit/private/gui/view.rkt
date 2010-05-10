#lang racket/base
(require racket/class
         unstable/class-iop
         racket/list
         racket/gui
         framework
         mrlib/hierlist
         "interfaces.rkt"
         "config.rkt"
         "model2rml.rkt"
         "rml.rkt")

(provide make-view-frame
         view%)

(define style-map racunit-style-map)

#|

To avoid getting sequence contract violations from editors, all editor
mutations should be done in the eventspace thread.

Can an update to a result<%> occur before its view link has been
created? Answer = yes, quite easily it seems (I tried it.)

See 'do-model-update': we yield if the view-link hasn't been created
yet, since there should be a callback queued waiting to create it.

With the 'queue-callback' calls and the one 'yield' call in place, I'm
no longer able to trigger the race condition.

----

FIXME:

Another problem: If tests are still running and a gui element "goes
away", then get errors. Eg, run (test/gui success-and-failure-tests)
and then immediately close the window.

Why are these things actually disappearing, though? Shouldn't they
still be there, just not visible?

|#


;; View
(define view%
  (class* object% (view<%>)
    (init-field parent
                controller)
    (super-new)

    (define editor (new ext:text% (style-map racunit-style-map)))
    (define renderer
      (new model-renderer%
           (controller controller)
           (editor editor)))

    (define eventspace
      (send (send parent get-top-level-window) get-eventspace))

    (define -hpane (new panel:horizontal-dragable% (parent parent)))
    (define -lpane (new vertical-pane% (parent -hpane)))
    (define -rpane (new vertical-pane% (parent -hpane)))
    (define -details-canvas 
      (new canvas:wide-snip% (parent -rpane) (editor editor)))

    (define tree-view
      (new model-tree-view%
           (parent -lpane) ;; tree-panel
           (view this)
           (controller controller)))

    (send editor lock #t)
    (with-handlers ([exn:fail? void])
      (send -hpane set-percentages VIEW-PANE-PERCENTS))

    ;; View Links

    (define/public (create-view-link model parent)
      (parameterize ((current-eventspace eventspace))
        (queue-callback
         (lambda ()
           (send tree-view create-view-link model parent)))))

    (define/private (get-view-link model)
      (send tree-view get-view-link model))

    ;; Methods

    (define/private (get-selected-model)
      (send/i controller controller<%> get-selected-model))

    (send/i controller controller<%> listen-selected-model
            (lambda (model)
              (parameterize ((current-eventspace eventspace))
                (queue-callback
                 (lambda ()
                   (let ([view-link (get-view-link model)])
                     (send view-link select #t))
                   (show-model model))))))

    ;; Update Management

    (define update-queue (make-hasheq))
    (define update-lock (make-semaphore 1))

    ;; queue-for-update : model -> void
    (define/public (queue-for-update model)
      (semaphore-wait update-lock)
      (hash-set! update-queue model #t)
      (semaphore-post update-lock)
      (process-updates))

    ;; process-updates : -> void
    (define/private (process-updates)
      (parameterize ((current-eventspace eventspace))
        (queue-callback
         (lambda ()
           (let ([models-to-update (grab+clear-update-queue)])
             (for ([model models-to-update])
               (do-model-update model)))))))

    ;; grab+clear-update-queue : -> void
    ;; ** Must be called from eventspace thread.
    (define/private (grab+clear-update-queue)
      (semaphore-wait update-lock)
      (if (positive? (hash-count update-queue))
          (let ([old-queue update-queue])
            (set! update-queue (make-hasheq))
            (semaphore-post update-lock)
            (reverse
             (hash-map old-queue (lambda (k v) k))))
          (begin (semaphore-post update-lock)
                 null)))

    ;; do-model-update : model<%> -> void
    ;; ** Must be called from eventspace thread.
    (define/private (do-model-update model)
      (let ([view-link (get-view-link model)])
        (cond [view-link
               (send tree-view update-item view-link)
               (when (eq? model (get-selected-model))
                 (show-model model))]
              [(not view-link)
               ;; If the view-link has not been created,
               ;; yield until it is.
               (unless (yield)
                 (error 'racunit-gui
                        "internal error: no progress waiting for view-link"))
               (do-model-update model)])))

    ;; Update display

    ;; show-model : result<%> -> void
    ;; Displays the result in the Details area.
    ;; ** Must be called from eventspace thread.
    (define/private (show-model model)
      (send* editor
        (begin-edit-sequence)
        (lock #f)
        (erase))
      (send renderer render-model/long model)
      (send* editor
        (lock #t)
        (end-edit-sequence)
        (scroll-to-position 0)))

    ))


;; tree-view% <: hierarchical-list%
(define model-tree-view%
  (class* hierarchical-list% ()
    (init-field view
                controller)
    (super-new (style '(auto-hscroll)))

    (inherit get-items)

    ;; View Link

    (define model=>view-link (make-hasheq))

    (define/public (set-view-link model item)
      (hash-set! model=>view-link model item))
    (define/public (get-view-link model)
      (hash-ref model=>view-link model #f))

    ;; Behavior

    (define/override (on-select item)
      (let [(model (send item user-data))]
        (send/i controller controller<%> set-selected-model model)))

    (define/override (on-double-select item)
      (when (is-a? item hierarchical-list-compound-item<%>)
        (if (send item is-open?)
            (send item close)
            (send item open))))

    (define/private (ensure-tree-visible model)
      (let* [(parent (send model get-parent))
             (parent-view-link (and parent (get-view-link parent)))]
        (when (and parent (not (send parent-view-link is-open?)))
          (ensure-tree-visible parent)
          (send parent-view-link open))))

    ;; Construction

    ;; create-view-link : result<%> suite-result<%>/#f-> item
    (define/public (create-view-link model parent)
      (let ([parent-link
             (if parent
                 (get-view-link parent)
                 this)])
        (initialize-view-link (cond [(is-a? model suite<%>)
                                     (send parent-link new-list)]
                                    [(is-a? model case<%>)
                                     (send parent-link new-item)])
                              model)))

    ;; initialize-view-link : result<%> (U compound-item% item%) -> item
    (define/private (initialize-view-link item model)
      (set-view-link model item)
      (send item user-data model)
      (insert-text (send item get-editor)
                   (send model get-name)
                   (send style-map get-style
                         (if (is-a? model suite<%>)
                             'bold
                             'normal))))

    ;; update-item : item% -> void
    (define/public (update-item view-link)
      (let* ([editor (send view-link get-editor)]
             [model (send view-link user-data)]
             [name (send/i model result<%> get-name)]
             [style-name
              (cond [(not (send/i model result<%> finished?)) 'test-unexecuted]
                    [(send/i model result<%> success?) 'test-success]
                    [(send/i model result<%> failure?) 'test-failure]
                    [(send/i model result<%> error?) 'test-error])]
             [style (send/i style-map style-map<%> get-style style-name)]
             [output? (send/i model result<%> has-output?)]
             [trash? (send/i model result<%> has-trash?)])
        (send editor begin-edit-sequence #f)
        (send editor delete (string-length name) (send editor last-position) #f)
        (when (or output? trash?)
          (send editor insert
                (output-icon)
                (string-length name)
                'same
                #f))
        (send editor change-style style 0 (send editor last-position) #f)
        (send editor end-edit-sequence)))))


;; view-frame% <: frame%
(define view-frame%
  (class (frame:standard-menus-mixin 
           (frame:basic-mixin frame%))

    (init [width (pref:width)]
          [height (pref:height)])
    (super-new (width width) (height height))

    (inherit get-help-menu
             get-width
             get-height)

    (define-syntax override-false
      (syntax-rules ()
        [(override-false name ...)
         (begin (define/override (name . _) #f) ...)]))

    (override-false file-menu:create-new?
                    file-menu:create-open?
                    file-menu:create-open-recent?
                    file-menu:create-revert?
                    file-menu:create-save?
                    file-menu:create-save-as?
                    file-menu:create-print?
                    edit-menu:create-undo?
                    edit-menu:create-redo?
                    edit-menu:create-cut?
                    edit-menu:create-paste?
                    edit-menu:create-clear?
                    edit-menu:create-find?
                    #;edit-menu:create-replace-and-find-again?
                    edit-menu:create-preferences?)

    (define/augment (on-close)
      (pref:width (get-width))
      (pref:height (get-height))
      (inner (void) on-close))

    (send (get-help-menu) delete)))

;; make-view-frame : -> frame%
(define (make-view-frame)
  (let ([frame 
         (new view-frame%
              (label FRAME-LABEL))])
    (send frame show #t)
    frame))