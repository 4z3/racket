#lang plai/mutator
(allocator-setup "../good-collectors/good-collector.ss" 58)

(define x 'initial)

(eq? x x)
(eq? x 'initial)
(eq? 5 4)