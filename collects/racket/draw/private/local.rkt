#lang scheme/base
(require scheme/class)

(provide (all-defined-out))

(define-local-member-name
  ;; various
  adjust-lock

  ;; bitmap%
  get-cairo-surface
  get-cairo-alpha-surface
  release-bitmap-storage
  get-bitmap-gl-context

  ;; bitmap-dc%
  internal-get-bitmap
  internal-set-bitmap

  ;; dc%
  in-cairo-context
  get-clipping-matrix

  ;; region%
  install-region
  lock-region

  ;; font% and dc-backend<%>
  get-pango

  ;; font%
  get-ps-pango
  get-font-key

  ;; dc-backend<%>
  get-cr
  release-cr
  end-cr
  reset-cr
  flush-cr
  init-cr-matrix
  get-font-metrics-key
  install-color
  dc-adjust-smoothing
  can-combine-text?
  can-mask-bitmap?)
