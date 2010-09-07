#lang racket/base
(require racket/class
         racket/draw/dc
         racket/draw/bitmap-dc
         racket/draw/bitmap
         racket/draw/local
         "../../lock.rkt"
         "queue.rkt")

(provide backing-dc%
         
         ;; scoped method names:
         get-backing-size
         queue-backing-flush
         on-backing-flush
         start-backing-retained
         end-backing-retained
         reset-backing-retained
         get-bitmap%)

(define-local-member-name
  get-backing-size
  queue-backing-flush
  on-backing-flush
  start-backing-retained
  end-backing-retained
  reset-backing-retained
  get-bitmap%)

(define backing-dc%
  (class (dc-mixin bitmap-dc-backend%)
    (inherit call-with-cr-lock
             internal-get-bitmap
             internal-set-bitmap
             reset-cr)

    (super-new)

    ;; Override this method to get the right size
    (define/public (get-backing-size xb yb)
      (set-box! xb 1)
      (set-box! yb 1))

    ;; override this method to set up a callback to
    ;;  `on-backing-flush' when the backing store can be rendered
    ;;  to the screen; called atomically (expecting no exceptions)
    (define/public (queue-backing-flush)
      (void))

    (define retained-cr #f)
    (define retained-counter 0)
    (define needs-flush? #f)

    ;; called with a procedure that is applied to a bitmap;
    ;;  returns #f if there's nothing to flush
    (define/public (on-backing-flush proc)
      (cond
       [(not retained-cr) #f]
       [(positive? retained-counter) 
        (proc (internal-get-bitmap)) 
        #t]
       [else 
        (reset-backing-retained proc)
        #t]))

    (define/public (reset-backing-retained [proc void])
      (let ([cr retained-cr])
        (when cr
          (let ([bm (internal-get-bitmap)])
            (set! retained-cr #f)
            (internal-set-bitmap #f #t)
            (super release-cr retained-cr)
            (proc bm)
            (release-backing-bitmap bm)))))

    (define/public (start-backing-retained)
      (call-with-cr-lock
       (lambda () 
         (set! retained-counter (add1 retained-counter)))))

    (define/public (end-backing-retained)
      (call-with-cr-lock
       (lambda () 
         (if (zero? retained-counter)
             (log-error "unbalanced end-on-paint")
             (set! retained-counter (sub1 retained-counter))))))

    (define/public (get-bitmap%) bitmap%)

    (define/override (get-cr)
      (or retained-cr
          (let ([w (box 0)]
                [h (box 0)])
            (get-backing-size w h)
            (let ([bm (get-backing-bitmap (get-bitmap%) (unbox w) (unbox h))])
              (internal-set-bitmap bm #t))
            (let ([cr (super get-cr)])
              (set! retained-cr cr)
              (reset-cr cr)
              cr))))

    (define/override (release-cr cr)
      (when (zero? flush-suspends)
        (queue-backing-flush)))

    (define flush-suspends 0)

    (define/override (suspend-flush) 
      (atomically
       (set! flush-suspends (add1 flush-suspends))))
    (define/override (resume-flush)  
      (atomically 
       (set! flush-suspends (sub1 flush-suspends))
       (when (zero? flush-suspends)
         (queue-backing-flush))))))

(define (get-backing-bitmap bitmap% w h)
  (make-object bitmap% w h #f #t))

(define (release-backing-bitmap bm)
  (send bm release-bitmap-storage))