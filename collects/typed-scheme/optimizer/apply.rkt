#lang scheme/base
(require syntax/parse
         syntax/id-table racket/dict
         unstable/match scheme/match
         (for-template scheme/unsafe/ops racket/base (prefix-in k: '#%kernel))
         (for-syntax racket/base)
         "../utils/utils.rkt"
         (rep type-rep)
         (types abbrev type-table utils subtype)
         (optimizer utils))

(provide apply-opt-expr)

(define-syntax-class apply-op
  #:literals (+ *)
  (pattern + #:with identity #'0)
  (pattern * #:with identity #'1))

(define-syntax-class apply-opt-expr
		     #:literals (k:apply map #%plain-app #%app)
  (pattern (#%plain-app k:apply op:apply-op (#%plain-app map f l))
           #:with opt
           (begin (reset-unboxed-gensym)
           (with-syntax ([(f* lp v lst) (map unboxed-gensym '(f* loop v lst))]
			 [l ((optimize) #'l)]
			 [f ((optimize) #'f)])
	     (log-optimization "apply-map" #'op)
	     #'(let ([f* f])
                 (let lp ([v op.identity] [lst l])
                   (if (null? lst)
                       v
                       (lp (op v (f* (unsafe-car lst))) (unsafe-cdr lst)))))))))