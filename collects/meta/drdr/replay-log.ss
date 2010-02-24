#lang scheme
(require "replay.ss"
         "cache.ss"
         "run-collect.ss")

; XXX Rewrite to work with logs in dbm

(define the-log-file
  (command-line
   #:program "replay-log"
   #:args (filename)
   filename))

(define the-log
  (read-cache the-log-file))

(unless (status? the-log)
  (error 'replay-log "Not an output log: ~e" the-log))

(replay-status the-log)
(replay-exit-code the-log)