
(module embed-unit scheme/base
  (require scheme/unit
	   scheme/path
           scheme/file
	   scheme/port
	   scheme/promise
           syntax/moddep
           syntax/modcollapse
           xml/plist
           setup/dirs
           setup/variant
	   "embed-sig.ss"
	   "private/winicon.ss"
           "private/winsubsys.ss"
	   "private/macfw.ss"
	   "private/mach-o.ss"
	   "private/windlldir.ss"
	   "private/collects-path.ss")
  
  (provide compiler:embed@)
  
  (define-unit compiler:embed@
    (import)
    (export compiler:embed^)
    
    (define (embedding-executable-is-directory? mred?)
      #f)
    
    (define (embedding-executable-is-actually-directory? mred?)
      (and mred? (eq? 'macosx (system-type))))
    
    (define (embedding-executable-put-file-extension+style+filters mred?)
      (case (system-type)
        [(windows) (values "exe" null '(("Executable" "*.exe")))]
        [(macosx) (if mred?
                      (values "app" '(enter-packages) '(("App" "*.app")))
                      (values #f null null))]
        [else (values #f null null)]))
    
    (define (embedding-executable-add-suffix path mred?)
      (let* ([path (if (string? path)
                       (string->path path)
                       path)]
             [fixup (lambda (re sfx)
                      (if (regexp-match re (path->bytes path))
                          path
                          (path-replace-suffix path sfx)))])
        (case (system-type)
          [(windows) (fixup #rx#"[.][eE][xX][eE]$" #".exe")]
          [(macosx) (if mred?
                        (fixup #rx#"[.][aA][pP][pP]$" #".app")
                        path)]
          [else path])))
    
    (define (mac-dest->executable dest mred?)
      (if mred?
          (let-values ([(base name dir?) (split-path dest)])
            (build-path dest
                        "Contents" "MacOS"
                        (path-replace-suffix name #"")))
          dest))
    
    ;; Find executable relative to the "mzlib"
    ;; collection.
    (define (find-exe mred? variant)
      (let* ([base (if mred?
                       (find-gui-bin-dir)
                       (find-console-bin-dir))]
             [fail
              (lambda ()
                (error 'create-embedding-executable
                       "can't find ~a executable for variant ~a"
                       (if mred? "GRacket" "Racket")
                       variant))])
        (let ([exe (build-path
                    base
                    (case (system-type)
                      [(macosx)
                       (cond
                         [(not mred?)
                          ;; Need Racket:
                          (string-append "racket" (variant-suffix variant #f))]
                         [mred?
                          ;; Need GRacket:
                          (let ([sfx (variant-suffix variant #t)])
                            (build-path (format "GRacket~a.app" sfx)
                                        "Contents" "MacOS" 
                                        (format "GRacket~a" sfx)))])]
                      [(windows)
                       (format "~a~a.exe" (if mred?
                                              "Gracket"
                                              "Racket")
                               (variant-suffix variant #t))]
                      [(unix)
                       (format "~a~a" (if mred?
                                          "gracket"
                                          "racket")
                               (variant-suffix variant #f))]))])
          (unless (or (file-exists? exe)
                      (directory-exists? exe))
            (fail))
          exe)))
    
    (define exe-suffix?
      (delay (equal? #"i386-cygwin" (path->bytes (system-library-subpath)))))
    
    ;; Find the magic point in the binary:
    (define (find-cmdline what rx)
      (let ([m (regexp-match-positions rx (current-input-port))])
        (if m
            (caar m)
            (error 
             'create-embedding-executable
             (format
              "can't find ~a position in executable"
              what)))))
    
    
    (define (relativize exec-name dest adjust)
      (let ([p (find-relative-path
                (let-values ([(dir name dir?) (split-path 
                                               (normal-case-path
                                                (normalize-path dest)))])
                  dir)
                (normal-case-path (normalize-path exec-name)))])
        (if (relative-path? p)
            (adjust p)
            p)))
    
    ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    (define (prepare-macosx-mred exec-name dest aux variant)
      (let* ([name (let-values ([(base name dir?) (split-path dest)])
                     (path-replace-suffix name #""))]
             [src (collection-file-path "Starter.app" "launcher")]
             [creator (let ([c (assq 'creator aux)])
                        (or (and c
                                 (cdr c))
                            "MrSt"))]
             [file-types (let ([m (assq 'file-types aux)])
                           (and m
                                (pair? (cdr m))
                                (cdr m)))]
             [uti-exports (let ([m (assq 'uti-exports aux)])
                            (and m
                                 (pair? (cdr m))
                                 (cdr m)))]
             [resource-files (let ([m (assq 'resource-files aux)])
                               (and m
                                    (cdr m)))])
        (when creator
          (unless (and (string? creator) (= 4 (string-length creator)))
            (error 'make-executable "creator is not a 4-character string: ~e" creator)))
        (when file-types
          (unless (and (list? file-types)
                       (andmap list? file-types)
                       (andmap (lambda (spec)
                                 (andmap (lambda (p)
                                           (and (list? p)
                                                (= 2 (length p))
                                                (string? (car p))))
                                         spec))
                               file-types))
            (error 'make-executable "bad file-types spec: ~e" file-types)))
        (when resource-files
          (unless (and (list? resource-files)
                       (andmap path-string?
                               resource-files))
            (error 'make-executable "resource-files is not a list of paths: ~e" resource-files)))
        
        (when (or (directory-exists? dest)
                  (file-exists? dest)
                  (link-exists? dest))
          (delete-directory/files dest))
        (make-directory* (build-path dest "Contents" "Resources"))
        (make-directory* (build-path dest "Contents" "MacOS"))
        (copy-file exec-name (build-path dest "Contents" "MacOS" name))
        (copy-file (build-path src "Contents" "PkgInfo")
                   (build-path dest "Contents" "PkgInfo"))
        (let ([icon (or (let ([icon (assq 'icns aux)])
                          (and icon
                               (cdr icon)))
                        (build-path src "Contents" "Resources" "Starter.icns"))])
          (copy-file icon
                     (build-path dest "Contents" "Resources" "Starter.icns")))
        (let ([orig-plist (call-with-input-file (build-path src
                                                            "Contents"
                                                            "Info.plist")
                            read-plist)]
              [plist-replace (lambda (plist . l)
                               (let loop ([plist plist][l l])
                                 (if (null? l)
                                     plist
                                     (let ([key (car l)]
                                           [val (cadr l)])
                                       (loop `(dict
                                               ,@(let loop ([c (cdr plist)])
                                                   (cond
                                                     [(null? c) (list (list 'assoc-pair key val))]
                                                     [(string=? (cadar c) key)
                                                      (cons (list 'assoc-pair key val)
                                                            (cdr c))]
                                                     [else
                                                      (cons (car c)
                                                            (loop (cdr c)))])))
                                             (cddr l))))))])
          (let* ([new-plist (plist-replace
                             orig-plist
                             
                             "CFBundleExecutable" 
                             (path->string name)
                             
                             "CFBundleSignature"
                             creator
                             
                             "CFBundleIdentifier" 
                             (format "org.racket-lang.~a" (path->string name)))]
                 [new-plist (if uti-exports
                                (plist-replace
                                 new-plist
                                 "UTExportedTypeDeclarations"
                                 (cons 'array
                                       (map (lambda (spec)
                                              (cons
                                               'dict
                                               (map (lambda (p)
                                                      (list
                                                       'assoc-pair
                                                       (car p)
                                                       (cadr p)))
                                                    spec)))
                                            uti-exports)))
                                new-plist)]
                 [new-plist (if file-types
                                (plist-replace
                                 new-plist                                 
                                 "CFBundleDocumentTypes"
                                 (cons 'array
                                       (map (lambda (spec)
                                              (cons
                                               'dict
                                               (map (lambda (p)
                                                      (list
                                                       'assoc-pair
                                                       (car p)
                                                       (cadr p)))
                                                    spec)))
                                            file-types)))                                
                                new-plist)])
            (call-with-output-file (build-path dest 
                                               "Contents" 
                                               "Info.plist")
              #:exists 'truncate
              (lambda (port)
                (write-plist new-plist port)))))
        (call-with-output-file (build-path dest 
                                           "Contents" 
                                           "PkgInfo")
          #:exists 'truncate
          (lambda (port)
            (fprintf port "APPL~a" creator)))
        (when resource-files
          (for-each (lambda (p)
                      (let-values ([(base name dir?) (split-path p)])
                        (copy-file p (build-path dest
                                                 "Contents" 
                                                 "Resources"
                                                 name))))
                    resource-files))
        (build-path dest "Contents" "MacOS" name)))
    
    ;; The starter-info file is now disabled. The GRacket
    ;; command line is handled the same as the Racket command
    ;; line.
    (define use-starter-info? #f)
    (define (finish-osx-mred dest flags exec-name keep-exe? relative?)
      (call-with-output-file (build-path dest 
                                         "Contents" 
                                         "Resources" 
                                         "starter-info")
        #:exists 'truncate
        (lambda (port)
          (write-plist 
           `(dict ,@(if keep-exe?
                        `((assoc-pair "executable name"
                                      ,(path->string 
                                        (if relative?
                                            (relativize exec-name dest
                                                        (lambda (p)
                                                          (build-path 'up 'up 'up p)))
                                            exec-name))))
                        null)
                  (assoc-pair "stored arguments"
                              (array ,@flags)))
           port))))
    
    ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    ;; Represent modules with lists starting with the filename, so we
    ;; can use assoc:
    (define (make-mod normal-file-path normal-module-path 
                      code name prefix full-name relative-mappings 
                      runtime-paths runtime-module-syms
                      actual-file-path)
      (list normal-file-path normal-module-path code
            name prefix full-name relative-mappings 
            runtime-paths runtime-module-syms 
            actual-file-path))
    
    (define (mod-file m) (car m))
    (define (mod-mod-path m) (cadr m))
    (define (mod-code m) (caddr m))
    (define (mod-name m) (list-ref m 3))
    (define (mod-prefix m) (list-ref m 4))
    (define (mod-full-name m) (list-ref m 5))
    (define (mod-mappings m) (list-ref m 6))
    (define (mod-runtime-paths m) (list-ref m 7))
    (define (mod-runtime-module-syms m) (list-ref m 8))
    (define (mod-actual-file m) (list-ref m 9))
    
    (define (generate-prefix)
      (format "#%embedded:~a:" (gensym)))
    
    (define (normalize filename)
      (let ([f (simplify-path (cleanse-path filename))])
        ;; Use normal-case-path on just the base part, to avoid
        ;; changing the filename case (which should match the
        ;; module-name case within the file):
        (let-values ([(base name dir?) (split-path f)])
          (if (path? base)
              (build-path (normal-case-path base) name)
              f))))
    
    (define (is-lib-path? a)
      (or (and (pair? a)
               (eq? 'lib (car a)))
          (symbol? a)))

    (define (symbol-to-lib-form l)
      (if (symbol? l)
          `(lib ,(symbol->string l))
          l))
      
    (define (unix-style-split p)
      (let ([m (regexp-match #rx"^([^/]*)/(.*)$" p)])
        (if m
            (cons (cadr m) (unix-style-split (caddr m)))
            (list p))))
    
    (define (extract-last l)
      (let loop ([l l][dirs null])
        (if (null? (cdr l))
            (values (reverse dirs) (car l))
            (loop (cdr l) (cons (car l) dirs)))))
    
    (define (lib-module-filename collects-dest module-path)
      (let-values ([(dir file) 
                    (let ([s (lib-path->string module-path)])
                      (extract-last (unix-style-split s)))])
        (let ([p (build-path collects-dest
                             (apply build-path dir)
                             "compiled"
                             (path-add-suffix file #".zo"))])
          (let-values ([(base name dir?) (split-path p)])
            (make-directory* base)
            p))))

    (define (file-date f)
      (with-handlers ([exn:fail:filesystem? (lambda (x) -inf.0)])
        (file-or-directory-modify-seconds f)))
    
    (define-struct extension (path))
    
    ;; Loads module code, using .zo if there, compiling from .scm if not
    (define (get-code filename module-path codes prefixes verbose? collects-dest on-extension 
                      compiler expand-namespace get-extra-imports)
      (let ([a (assoc filename (unbox codes))])
        (if a
            ;; Already have this module. Make sure that library-referenced
            ;;  modules are consistently referenced through library paths:
            (let ([found-lib? (is-lib-path? (mod-mod-path a))]
                  [look-lib? (is-lib-path? module-path)])
              (cond
                [(and found-lib? look-lib?)
                 'ok]
                [(or found-lib? look-lib?)
                 (error 'find-module
                        "module referenced both as a library and through a path: ~a"
                        filename)]
                [else 'ok]))
            ;; First use of the module. Get code and then get code for imports.
            (begin
              (when verbose?
                (fprintf (current-error-port) "Getting ~s\n" filename))
              (let ([actual-filename filename]) ; `set!'ed below to adjust file suffix
                (let ([code (get-module-code filename
                                             "compiled"
                                             compiler
                                             (if on-extension
                                                 (lambda (f l?)
                                                   (on-extension f l?)
                                                   #f)
                                                 (lambda (file _loader?)
                                                   (if _loader?
                                                       (error 'create-embedding-executable
                                                              "cannot use a _loader extension: ~e"
                                                              file)
                                                       (make-extension file))))
                                             #:choose
                                             ;; Prefer extensions, if we're handling them:
                                             (lambda (src zo so)
                                               (set! actual-filename src) ; remember convert soure name
                                               (if on-extension
                                                   #f
                                                   (if (and (file-exists? so)
                                                            ((file-date so) . >= . (file-date zo)))
                                                       'so
                                                       #f))))]
                      [name (let-values ([(base name dir?) (split-path filename)])
                              (path->string (path-replace-suffix name #"")))]
                      [prefix (let ([a (assoc filename prefixes)])
                                (if a
                                    (cdr a)
                                    (generate-prefix)))])
                  (cond
                   [(extension? code)
                    (when verbose?
                      (fprintf (current-error-port) " using extension: ~s\n" (extension-path code)))
                    (set-box! codes
                              (cons (make-mod filename module-path code 
                                              name prefix (string->symbol
                                                           (format "~a~a" prefix name))
                                              null null null
                                              actual-filename)
                                    (unbox codes)))]
                   [code
                    (let ([importss (module-compiled-imports code)])
                      (let ([all-file-imports (filter (lambda (x) 
                                                        (let-values ([(x base) (module-path-index-split x)])
                                                          (not (and (pair? x)
                                                                    (eq? 'quote (car x))))))
                                                      (apply append (map cdr importss)))]
                            [extra-paths 
                             (map symbol-to-lib-form (get-extra-imports actual-filename code))])
                        (let* ([runtime-paths
                                (parameterize ([current-namespace expand-namespace])
                                  (eval code)
                                  (let ([module-path
                                         (if (path? module-path)
                                             (path->complete-path module-path)
                                             module-path)])
                                    (syntax-case (expand `(,#'module m mzscheme
                                                            (require (only ,module-path)
                                                                     mzlib/runtime-path)
                                                            (runtime-paths ,module-path))) (quote)
                                      [(_ m mz (#%mb rfs req (quote (spec ...))))
                                       (syntax->datum #'(spec ...))]
                                      [_else (error 'create-empbedding-executable
                                                    "expansion mismatch when getting external paths")])))]
                               
                              [extra-runtime-paths (filter
                                                    values
                                                    (map (lambda (p)
                                                           (and (pair? p)
                                                                (eq? (car p) 'module)
                                                                (cadr p)))
                                                         runtime-paths))])
                          (let ([sub-files (map (lambda (i) (normalize (resolve-module-path-index i filename)))
                                                all-file-imports)]
                                [sub-paths (map (lambda (i) (collapse-module-path-index i module-path))
                                                all-file-imports)]
                                [normalized-extra-paths (map (lambda (i) (collapse-module-path i module-path))
                                                             (append extra-runtime-paths extra-paths))]
                                [extra-files (map (lambda (i) (normalize (resolve-module-path-index (module-path-index-join i #f)
                                                                                                    filename)))
                                                  ;; getting runtime-module-path symbols below
                                                  ;; relies on extra-runtime-paths being first:
                                                  (append extra-runtime-paths extra-paths))])
                            ;; Get code for imports:
                            (for-each (lambda (sub-filename sub-path)
                                        (get-code sub-filename
                                                  sub-path
                                                  codes
                                                  prefixes
                                                  verbose?
                                                  collects-dest
                                                  on-extension
                                                  compiler
                                                  expand-namespace
                                                  get-extra-imports))
                                      (append sub-files extra-files)
                                      (append sub-paths normalized-extra-paths))
                            (when verbose?
                              (unless (null? runtime-paths)
                                (fprintf (current-error-port) "Runtime paths for ~s: ~s\n"
                                         filename
                                         runtime-paths)))
                            (if (and collects-dest
                                     (is-lib-path? module-path))
                                ;; Install code as .zo:
                                (begin
                                  (with-output-to-file (lib-module-filename collects-dest module-path)
                                    #:exists 'truncate/replace
                                    (lambda ()
                                      (write code)))
                                  ;; Record module as copied
                                  (set-box! codes
                                            (cons (make-mod filename module-path #f
                                                            #f #f #f #f 
                                                            null null
                                                            actual-filename)
                                                  (unbox codes))))
                                ;; Build up relative module resolutions, relative to this one,
                                ;; that will be requested at run-time.
                                (let ([mappings (map (lambda (sub-i sub-filename sub-path)
                                                       (and (not (and collects-dest
                                                                      (is-lib-path? sub-path)))
                                                            (let-values ([(path base) (module-path-index-split sub-i)])
                                                              (and base ; can be #f if path isn't relative
                                                                   (begin
                                                                     ;; Assert: base should refer to this module:
                                                                     (let-values ([(path2 base2) (module-path-index-split base)])
                                                                       (when (or path2 base2)
                                                                         (error 'embed "unexpected nested module path index")))
                                                                     (let ([m (assoc sub-filename (unbox codes))])
                                                                       (cons path (mod-full-name m))))))))
                                                     all-file-imports sub-files sub-paths)])
                                  ;; Record the module
                                  (set-box! codes
                                            (cons (make-mod filename module-path code 
                                                            name prefix (string->symbol
                                                                         (format "~a~a" prefix name))
                                                            (filter (lambda (p)
                                                                      (and p (cdr p)))
                                                                    mappings)
                                                            runtime-paths
                                                            ;; extract runtime-path module symbols:
                                                            (let loop ([runtime-paths runtime-paths]
                                                                       [extra-files extra-files])
                                                              (cond
                                                               [(null? runtime-paths) null]
                                                               [(let ([p (car runtime-paths)])
                                                                  (and (pair? p) (eq? (car p) 'module)))
                                                                (cons (mod-full-name (assoc (car extra-files) (unbox codes)))
                                                                      (loop (cdr runtime-paths) (cdr extra-files)))]
                                                               [else
                                                                (cons #f (loop (cdr runtime-paths) extra-files))]))
                                                            actual-filename)
                                                  (unbox codes)))))))))]
                   [else
                    (set-box! codes
                              (cons (make-mod filename module-path code 
                                              name #f #f
                                              null null
                                              actual-filename)
                                    (unbox codes)))])))))))
    
    ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    (define (compile-using-kernel e)
      (let ([ns (make-empty-namespace)])
        (namespace-attach-module (current-namespace) ''#%kernel ns)
        (parameterize ([current-namespace ns])
          (namespace-require ''#%kernel)
          (compile e))))

    ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    (define (lib-path->string path)
      (cond
       [(null? (cddr path))
        (if (regexp-match #rx"^[^/]*[.]" (cadr path))
            ;; mzlib
            (string-append "mzlib/" (cadr path))
            ;; new-style
            (if (regexp-match #rx"^[^/.]*$" (cadr path))
                (string-append (cadr path) "/main.ss")
                (if (regexp-match #rx"^[^.]*$" (cadr path))
                    ;; need a suffix:
                    (string-append (cadr path) ".ss")
                    (cadr path))))]
       [else
        ;; old-style multi-string:
        (string-append (apply string-append
                              (map (lambda (s)
                                     (string-append s "/"))
                                   (cddr path)))
                       (cadr path))]))
    
    (define (make-module-name-resolver code-l)
      (let ([extensions (filter (lambda (m) (extension? (mod-code m))) code-l)])
        `(module #%resolver '#%kernel
           (let-values ([(orig) (current-module-name-resolver)]
                        [(regs) (make-hasheq)]
                        [(mapping-table) (quote
                                          ,(map
                                            (lambda (m)
                                              `(,(mod-full-name m)
                                                ,(mod-mappings m)))
                                            code-l))]
                        [(library-table) (quote
                                          ,(filter values
                                                   (map (lambda (m)
                                                          (let ([path (mod-mod-path m)])
                                                            (cond
                                                             [(and (pair? path)
                                                                   (eq? 'lib (car path)))
                                                              (cons (lib-path->string path)
                                                                    (mod-full-name m))]
                                                             [(and (pair? path)
                                                                   (eq? 'planet (car path)))
                                                              ;; Normalize planet path
                                                              (cons (collapse-module-path path current-directory)
                                                                    (mod-full-name m))]
                                                             [else #f])))
                                                        code-l)))])
             (hash-set! regs 
                        (namespace-module-registry (current-namespace))
                        (vector mapping-table library-table))
             (letrec-values ([(embedded-resolver)
                              (case-lambda 
                               [(name)
                                ;; a notification; if the name matches one of our special names,
                                ;; assume that it's from a namespace that has the declaration
                                ;; [it would be better if the noritifer told us the source]
                                (let-values ([(name) (if name (resolved-module-path-name name) #f)])
                                  (let-values ([(a) (assq name mapping-table)])
                                    (if a
                                        (let-values ([(vec) (hash-ref regs (namespace-module-registry (current-namespace))
                                                                      (lambda ()
                                                                        (let-values ([(vec) (vector null null)])
                                                                          (hash-set! regs (namespace-module-registry (current-namespace)) vec)
                                                                          vec)))])
                                          ;; add mapping:
                                          (vector-set! vec 0 (cons a (vector-ref vec 0)))
                                          ;; add library mappings:
                                          (vector-set! vec 1 (append 
                                                              (letrec-values ([(loop)
                                                                               (lambda (l)
                                                                                 (if (null? l)
                                                                                     null
                                                                                     (if (eq? (cdar l) name)
                                                                                         (cons (car l) (loop (cdr l)))
                                                                                         (loop (cdr l)))))])
                                                                (loop library-table))
                                                              (vector-ref vec 1))))
                                        (void))))
                                (orig name)]
                               [(name rel-to stx)
                                (embedded-resolver name rel-to stx #t)]
                               [(name rel-to stx load?)
                                (if (not (module-path? name))
                                    ;; Bad input
                                    (orig name rel-to stx load?)
                                    (let-values ([(table-vec) (hash-ref regs (namespace-module-registry (current-namespace)) #f)])
                                      (if (not table-vec)
                                          ;; No mappings in this registry
                                          (orig name rel-to stx load?)
                                          (let-values ([(mapping-table) (vector-ref table-vec 0)]
                                                       [(library-table) (vector-ref table-vec 1)])
                                            ;; Have a relative mapping?
                                            (let-values ([(a) (if rel-to
                                                                  (assq (resolved-module-path-name rel-to) mapping-table)
                                                                  #f)]
                                                         [(ss->rkt)
                                                          (lambda (s)
                                                            (regexp-replace #rx"[.]ss$" s ".rkt"))])
                                              (if a
                                                  (let-values ([(a2) (assoc name (cadr a))])
                                                    (if a2
                                                        (make-resolved-module-path (cdr a2))
                                                        ;; No relative mapping found (presumably a lib)
                                                        (orig name rel-to stx load?)))
                                                  (let-values ([(lname)
                                                                ;; normalize `lib' to single string (same as lib-path->string):
                                                                (let-values ([(name)
                                                                              (if (symbol? name)
                                                                                  (list 'lib (symbol->string name))
                                                                                  name)])
                                                                  (if (pair? name)
                                                                      (if (eq? 'lib (car name))
                                                                          (if (null? (cddr name))
                                                                              (if (regexp-match #rx"^[^/]*[.]" (cadr name))
                                                                                  ;; mzlib
                                                                                  (string-append "mzlib/" (ss->rkt (cadr name)))
                                                                                  ;; new-style
                                                                                  (if (regexp-match #rx"^[^/.]*$" (cadr name))
                                                                                      (string-append (cadr name) "/main.rkt")
                                                                                      (if (regexp-match #rx"^[^.]*$" (cadr name))
                                                                                          ;; need a suffix:
                                                                                          (string-append (cadr name) ".rkt")
                                                                                          (ss->rkt (cadr name)))))
                                                                              ;; old-style multi-string
                                                                              (string-append (apply string-append
                                                                                                    (map (lambda (s)
                                                                                                           (string-append s "/"))
                                                                                                         (cddr name)))
                                                                                             (ss->rkt (cadr name))))
                                                                          (if (eq? 'planet (car name))
                                                                              (letrec-values ([(split)
                                                                                               (lambda (s rx suffix-after)
                                                                                                 (let-values ([(m) (regexp-match-positions 
                                                                                                                    rx
                                                                                                                    s)])
                                                                                                   (if m
                                                                                                       (cons (substring s 0 (caar m))
                                                                                                             (split (substring s (cdar m))
                                                                                                                    rx 
                                                                                                                    (- suffix-after 1)))
                                                                                                       (list
                                                                                                        (if (suffix-after . <= . 0)
                                                                                                            (if (regexp-match? #rx"[.]" s)
                                                                                                                s
                                                                                                                (string-append s ".rkt"))
                                                                                                            s)))))]
                                                                                              [(last-of)
                                                                                               (lambda (l)
                                                                                                 (if (null? (cdr l))
                                                                                                     (car l)
                                                                                                     (last-of (cdr l))))]
                                                                                              [(not-last)
                                                                                               (lambda (l)
                                                                                                 (if (null? (cdr l))
                                                                                                     null
                                                                                                     (cons (car l) (not-last (cdr l)))))])
                                                                                (if (null? (cddr name))
                                                                                    ;; need to normalize:
                                                                                    (let-values ([(s) (if (symbol? (cadr name))
                                                                                                          (symbol->string (cadr name))
                                                                                                          (cadr name))])
                                                                                      (let-values ([(parts) (split s #rx"/" 2)])
                                                                                        (let-values ([(vparts) (split (cadr parts) #rx":" +inf.0)])
                                                                                          (cons 'planet
                                                                                                (cons (if (null? (cddr parts))
                                                                                                          "main.rkt"
                                                                                                          (ss->rkt (last-of parts)))
                                                                                                      (cons
                                                                                                       (cons 
                                                                                                        (car parts) 
                                                                                                        (cons (string-append (car vparts) 
                                                                                                                             ".plt")
                                                                                                              (if (null? (cddr parts))
                                                                                                                  null
                                                                                                                  ;; FIXME: finish version parse:
                                                                                                                  (cdddr parts))))
                                                                                                       (if (null? (cddr parts))
                                                                                                           null
                                                                                                           (not-last (cddr parts)))))))))
                                                                                  ;; already in long form; move subcollects to end:
                                                                                  (let-values ([(s) (cadr name)])
                                                                                    (let-values ([(parts) (split s #rx"/" +inf.0)])
                                                                                      (if (= 1 (length parts))
                                                                                          (list* 'planet
                                                                                                 (ss->rkt (cadr name))
                                                                                                 (cddr name))
                                                                                          (list* 'planet
                                                                                                 (ss->rkt (last-of parts))
                                                                                                 (caddr name)
                                                                                                 (append
                                                                                                  (cdddr name)
                                                                                                  (not-last parts))))))))
                                                                              #f))
                                                                      #f))]
                                                               [(planet-match?)
                                                                (lambda (a b)
                                                                  (if (equal? (cons (car a) (cddr a))
                                                                              (cons (car b) (cddr b)))
                                                                      (let-values ([(a) (cadr a)]
                                                                                   [(b) (cadr b)])
                                                                        (if (equal? (car a) (car b))
                                                                            (if (equal? (cadr a) (cadr b))
                                                                                ;; Everything matches up to the version...
                                                                                ;; FIXME: check version. (Since the version isn't checked,
                                                                                ;; this currently works only when a single version of the
                                                                                ;; package is used in the executable.)
                                                                                #t
                                                                                #f)
                                                                            #f))
                                                                      #f))])
                                                    ;; A library mapping that we have? 
                                                    (let-values ([(a3) (if lname
                                                                           (if (string? lname)
                                                                               ;; lib
                                                                               (assoc lname library-table)
                                                                               ;; planet
                                                                               (ormap (lambda (e)
                                                                                        (if (string? (car e))
                                                                                            #f
                                                                                            (if (planet-match? (cdar e) (cdr lname))
                                                                                                e
                                                                                                #f)))
                                                                                      library-table))
                                                                           #f)])
                                                      (if a3
                                                          ;; Have it:
                                                          (make-resolved-module-path (cdr a3))
                                                          ;; Let default handler try:
                                                          (orig name rel-to stx load?))))))))))])])
               (current-module-name-resolver embedded-resolver))))))

    (define (ss<->rkt path)
      (cond
       [(regexp-match? #rx#"[.]ss$" path)
        (ss<->rkt (path-replace-suffix path #".rkt"))]
       [(regexp-match? #rx#"[.]rkt$" path)
        (if (file-exists? path)
            path
            (let ([p2 (path-replace-suffix path #".ss")])
              (if (file-exists? path)
                  p2
                  path)))]
       [else path]))
    
    ;; Write a module bundle that can be loaded with 'load' (do not embed it
    ;; into an executable). The bundle is written to the current output port.
    (define (do-write-module-bundle outp verbose? modules config? literal-files literal-expressions collects-dest
                                    on-extension program-name compiler expand-namespace 
                                    src-filter get-extra-imports)
      (let* ([module-paths (map cadr modules)]
             [resolve-one-path (lambda (mp)
                                 (let ([f (resolve-module-path mp #f)])
                                   (unless f
                                     (error 'write-module-bundle "bad module path: ~e" mp))
                                   (normalize f)))]
             [files (map resolve-one-path module-paths)]
             [collapse-one (lambda (mp)
                             (collapse-module-path mp (build-path (current-directory) "dummy.rkt")))]
             [collapsed-mps (map collapse-one module-paths)]
             [prefix-mapping (map (lambda (f m)
                                    (cons f (let ([p (car m)])
                                              (cond
                                                [(symbol? p) (symbol->string p)]
                                                [(eq? p #t) (generate-prefix)]
                                                [(not p) ""]
                                                [else (error
                                                       'write-module-bundle
                                                       "bad prefix: ~e"
                                                       p)]))))
                                  files modules)]
             ;; Each element is created with `make-mod'.
             ;; As we descend the module tree, we append to the front after
             ;; loading imports, so the list in the right order.
             [codes (box null)]
             [get-code-at (lambda (f mp)
                            (get-code f mp codes prefix-mapping verbose? collects-dest
                                           on-extension compiler expand-namespace
                                           get-extra-imports))]
             [__
              ;; Load all code:
              (for-each get-code-at files collapsed-mps)]
             [config-infos (if config?
                               (let ([a (assoc (car files) (unbox codes))])
                                 (let ([info (module-compiled-language-info (mod-code a))])
                                   (and info
                                        (let ([get-info ((dynamic-require (vector-ref info 0) (vector-ref info 1))
                                                         (vector-ref info 2))])
                                          (get-info 'configure-runtime null)))))
                               null)])
        ;; Add module for runtime configuration:
        (when config-infos
          (for ([config-info (in-list config-infos)])
            (let ([mp (vector-ref config-info 0)])
              (get-code-at (resolve-one-path mp)
                           (collapse-one mp)))))
        ;; Drop elements of `codes' that just record copied libs:
        (set-box! codes (filter mod-code (unbox codes)))
        ;; Bind `module' to get started:
        (write (compile-using-kernel '(namespace-require '(only '#%kernel module))) outp)
        ;; Install a module name resolver that redirects
        ;; to the embedded modules
        (write (make-module-name-resolver (filter mod-code (unbox codes))) outp)
        (write (compile-using-kernel '(namespace-require ''#%resolver)) outp)
        ;; Write the extension table and copy module code:
        (let* ([l (reverse (unbox codes))]
               [extensions (filter (lambda (m) (extension? (mod-code m))) l)]
               [runtimes (filter (lambda (m) (pair? (mod-runtime-paths m))) l)]
               [table-mod
                (if (null? runtimes)
                    #f
                    (let* ([table-sym (module-path-index-resolve 
                                       (module-path-index-join '(lib "runtime-path-table.rkt" "mzlib" "private")
                                                               #f))]
                           [table-path (resolved-module-path-name table-sym)])
                      (assoc (normalize table-path) l)))])
          (unless (null? extensions)
            ;; The extension table:`
            (write 
             `(module #%extension-table '#%kernel
                (#%require '#%utils)
                (let-values ([(eXtEnSiOn-modules) ;; this name is magic for the exe->distribution process
                              (quote ,(map (lambda (m)
                                             (let ([p (extension-path (mod-code m))])
                                               (when verbose?
                                                 (fprintf (current-error-port) "Recording extension at ~s\n" p))
                                               (list (path->bytes p)
                                                     (mod-full-name m)
                                                     ;; The program name isn't used. It just helps ensures that
                                                     ;; there's plenty of room in the executable for patching
                                                     ;; the path later when making a distribution.
                                                     (path->bytes program-name))))
                                           extensions))])
                  (for-each (lambda (pr)
                              (current-module-declare-name (make-resolved-module-path (cadr pr)))
                              (let-values ([(p) (bytes->path (car pr))])
                                (load-extension (if (relative-path? p)
                                                    (let-values ([(d) (current-directory)])
                                                      (current-directory (find-system-path 'orig-dir))
                                                      (begin0
                                                       (let-values ([(p2) (find-executable-path (find-system-path 'exec-file) p #t)])
                                                         (if p2
                                                             p2
                                                             (path->complete-path p (current-directory))))
                                                       (current-directory d)))
                                                    p))))
                            eXtEnSiOn-modules)))
             outp)
            (write (compile-using-kernel '(namespace-require ''#%extension-table)) outp))
          ;; Runtime-path table:
          (unless (null? runtimes)
            (unless table-mod
              (error 'create-embedding-executable "cannot find module for runtime-path table"))
            (write (compile-using-kernel
                    `(current-module-declare-name (make-resolved-module-path 
                                                   ',(mod-full-name table-mod))))
                   outp)
            (write `(module runtime-path-table '#%kernel
                      (#%provide table)
                      (define-values (table)
                        (make-immutable-hash
                         (let-values ([(rUnTiMe-paths) ; this is a magic name for exe->distribution process
                                       ',(apply append
                                                (map (lambda (nc)
                                                       (map (lambda (p sym)
                                                              (list
                                                               (cons (mod-full-name nc)
                                                                     (if (path? p)
                                                                         (path->bytes p)
                                                                         (if (and (pair? p)
                                                                                  (eq? 'module (car p)))
                                                                             (list 'module (cadr p))
                                                                             p)))
                                                               (let ([p (cond
                                                                         [(bytes? p) (bytes->path p)]
                                                                         [(and (list? p) (= 2 (length p)) 
                                                                               (eq? 'so (car p)))
                                                                          (let ([fs (list
                                                                                     (cadr p)
                                                                                     (path-replace-suffix (cadr p) 
                                                                                                          (system-type 'so-suffix)))])
                                                                            (ormap (lambda (f)
                                                                                     (ormap (lambda (p)
                                                                                              (let ([p (build-path p f)])
                                                                                                (and (or (file-exists? p)
                                                                                                         (directory-exists? p))
                                                                                                     p)))
                                                                                            (get-lib-search-dirs)))
                                                                                   fs))]
                                                                         [(and (list? p)
                                                                               (eq? 'lib (car p)))
                                                                          (let ([p (if (null? (cddr p))
                                                                                       (if (regexp-match #rx"^[^/]*[.]" (cadr p))
                                                                                           p
                                                                                           (let ([s (regexp-split #rx"/" (cadr p))])
                                                                                             (if (null? (cdr s))
                                                                                                 `(lib "main.rkt" ,(cadr p))
                                                                                                 (let ([s (reverse s)])
                                                                                                   `(lib ,(car s) ,@(reverse (cdr s)))))))
                                                                                       p)])
                                                                            (ss<->rkt
                                                                             (apply collection-file-path
                                                                                    (cadr p)
                                                                                    (if (null? (cddr p))
                                                                                        (list "mzlib")
                                                                                        (cddr p)))))]
                                                                         [(and (list? p)
                                                                               (eq? 'module (car p)))
                                                                          sym]
                                                                         [else p])])
                                                                 (and p
                                                                      (if (symbol? p)
                                                                          p
                                                                          (path->bytes 
                                                                           (if (absolute-path? p)
                                                                               p
                                                                               (build-path (path-only (mod-file nc)) p))))))
                                                               ;; As for the extension table, a placeholder to save 
                                                               ;; room likely needed by the distribution-mangler
                                                               (bytes-append #"................." (path->bytes program-name))))
                                                            (mod-runtime-paths nc)
                                                            (mod-runtime-module-syms nc)))
                                                     runtimes))])
                           rUnTiMe-paths))))
                   outp))
          ;; Copy module code:
          (for-each
           (lambda (nc)
             (unless (or (extension? (mod-code nc))
                         (eq? nc table-mod))
               (when verbose?
                 (fprintf (current-error-port) "Writing module from ~s\n" (mod-file nc)))
               (write (compile-using-kernel
                       `(current-module-declare-name 
                         (make-resolved-module-path
                          ',(mod-full-name nc))))
                      outp)
               (if (src-filter (mod-actual-file nc))
                   (call-with-input-file* (mod-actual-file nc)
                     (lambda (inp)
                       (copy-port inp outp)))
                   (write (mod-code nc) outp))))
           l))
        (write (compile-using-kernel '(current-module-declare-name #f)) outp)
        ;; Remove `module' binding before we start running user code:
        (write (compile-using-kernel '(namespace-set-variable-value! 'module #f #t)) outp)
        (write (compile-using-kernel '(namespace-undefine-variable! 'module)) outp)
        (newline outp)
        (when config-infos
          (for ([config-info (in-list config-infos)])
            (let ([a (assoc (resolve-one-path (vector-ref config-info 0)) (unbox codes))])            
              (write (compile-using-kernel `((dynamic-require '',(mod-full-name a)
                                                              ',(vector-ref config-info 1))
                                             ',(vector-ref config-info 2)))
                     outp))))
        (for-each (lambda (f)
                    (when verbose?
                      (fprintf (current-error-port) "Copying from ~s\n" f))
                    (call-with-input-file* f
                      (lambda (i)
                        (copy-port i outp))))
                  literal-files)
        (for-each (lambda (v) (write v outp)) literal-expressions)))

    (define (write-module-bundle #:verbose? [verbose? #f]
                                 #:modules [modules null]
                                 #:configure-via-first-module? [config? #f]
                                 #:literal-files [literal-files null]
                                 #:literal-expressions [literal-expressions null]
                                 #:on-extension [on-extension #f]
                                 #:expand-namespace [expand-namespace (current-namespace)]
                                 #:compiler [compiler (lambda (expr)
                                                        (parameterize ([current-namespace expand-namespace])
                                                          (compile expr)))]
                                 #:src-filter [src-filter (lambda (filename) #f)]
                                 #:get-extra-imports [get-extra-imports (lambda (filename code) null)])
      (do-write-module-bundle (current-output-port) verbose? modules config? literal-files literal-expressions
                              #f ; collects-dest
                              on-extension
                              "?" ; program-name 
                              compiler expand-namespace 
                              src-filter get-extra-imports))

    
    ;; The old interface:
    (define make-embedding-executable
      (lambda (dest mred? verbose? 
                    modules 
                    literal-files literal-expression
                    cmdline
                    [aux null]
                    [launcher? #f]
                    [variant (system-type 'gc)])
        (create-embedding-executable dest
                                     #:mred? mred?
                                     #:verbose? verbose?
                                     #:modules modules
                                     #:literal-files literal-files
                                     #:literal-expression literal-expression
                                     #:cmdline cmdline
                                     #:aux aux
                                     #:launcher? launcher?
                                     #:variant variant)))
    
    ;; Use `write-module-bundle', but figure out how to put it into an executable
    (define (create-embedding-executable dest
                                         #:mred? [really-mred? #f]
                                         #:gracket? [gracket? #f]
                                         #:verbose? [verbose? #f]
                                         #:modules [modules null]
                                         #:configure-via-first-module? [config? #f]
                                         #:literal-files [literal-files null]
                                         #:literal-expression [literal-expression #f]
                                         #:literal-expressions [literal-expressions
                                                                (if literal-expression
                                                                    (list literal-expression)
                                                                    null)]
                                         #:cmdline [cmdline null]
                                         #:aux [aux null]
                                         #:launcher? [launcher? #f]
                                         #:variant [variant (system-type 'gc)]
                                         #:collects-path [collects-path #f]
                                         #:collects-dest [collects-dest #f]
                                         #:on-extension [on-extension #f]
                                         #:expand-namespace [expand-namespace (current-namespace)]
                                         #:compiler [compiler (lambda (expr)
                                                                (parameterize ([current-namespace expand-namespace])
                                                                  (compile expr)))]
                                         #:src-filter [src-filter (lambda (filename) #f)]
                                         #:get-extra-imports [get-extra-imports (lambda (filename code) null)])
      (define mred? (or really-mred? gracket?))
      (define keep-exe? (and launcher?
                             (let ([m (assq 'forget-exe? aux)])
                               (or (not m)
                                   (not (cdr m))))))
      (define unix-starter? (and (eq? (system-type) 'unix)
                                 (let ([m (assq 'original-exe? aux)])
                                   (or (not m)
                                       (not (cdr m))))))
      (define long-cmdline? (or (eq? (system-type) 'windows)
                                (and use-starter-info? mred? (eq? 'macosx (system-type)))
                                unix-starter?))
      (define relative? (let ([m (assq 'relative? aux)])
                          (and m (cdr m))))
      (define collects-path-bytes (collects-path->bytes 
                                   ((if (and mred?
                                             (eq? 'macosx (system-type)))
                                        mac-mred-collects-path-adjust
                                        values)
                                    collects-path)))
      (define word-size (if (fixnum? (expt 2 32)) 8 4))
      (unless (or long-cmdline?
                  ((apply +
                          (map (lambda (s)
                                 (+ word-size (bytes-length (string->bytes/utf-8 s))))
                               cmdline)) . < . 80))
        (error 'create-embedding-executable "command line too long: ~e" cmdline))
      (check-collects-path 'create-embedding-executable collects-path collects-path-bytes)
      (let ([exe (find-exe mred? variant)])
        (when verbose?
          (fprintf (current-error-port) "Copying to ~s\n" dest))
        (let-values ([(dest-exe orig-exe osx?)
                      (cond
                        [(and mred? (eq? 'macosx (system-type)))
                         (values (prepare-macosx-mred exe dest aux variant) #f #t)]
                        [unix-starter?
                         (let ([starter (build-path (find-lib-dir) 
                                                    (if (force exe-suffix?)
                                                        "starter.exe"
                                                        "starter"))])
                           (when (or (file-exists? dest)
                                     (directory-exists? dest)
                                     (link-exists? dest))
                             (delete-file dest))
                           (copy-file starter dest)
                           (values dest starter #f))]
                        [else
                         (when (or (file-exists? dest)
                                   (directory-exists? dest)
                                   (link-exists? dest))
                           ;; Delete-file isn't enough if the target
                           ;;  is supposed to be a directory. But
                           ;;  currently, that happens only for GRacket 
                           ;;  on Mac OS X, which is handled above.
                           (delete-file dest))
                         (copy-file exe dest)
                         (values dest exe #f)])])
          (with-handlers ([void (lambda (x)
                                  (if osx?
                                      (when (directory-exists? dest)
                                        (delete-directory/files dest))
                                      (when (file-exists? dest)
                                        (delete-file dest)))
                                  (raise x))])
            (when (and (eq? 'macosx (system-type))
                       (not unix-starter?))
              (let ([m (assq 'framework-root aux)])
                (if m
                    (when (cdr m)
                      (update-framework-path (cdr m) 
                                             (mac-dest->executable dest mred?)
                                             mred?))
                    ;; Check whether we need an absolute path to frameworks:
                    (let ([dest (mac-dest->executable dest mred?)])
                      (when (regexp-match #rx"^@executable_path" 
                                          (get-current-framework-path dest "Racket"))
                        (update-framework-path (string-append
                                                (path->string (find-lib-dir))
                                                "/")
                                               dest
                                               mred?))))))
            (when (eq? 'windows (system-type))
              (let ([m (assq 'dll-dir aux)])
                (if m
                    (when (cdr m)
                      (update-dll-dir dest (cdr m)))
                    ;; Check whether we need an absolute path to DLLs:
                    (let ([dir (get-current-dll-dir dest)])
                      (when (relative-path? dir)
                        (let-values ([(orig-dir name dir?) (split-path 
                                                            (path->complete-path orig-exe))])
                          (update-dll-dir dest (build-path orig-dir dir))))))))
            (let ([write-module
                   (lambda (s)
                     (do-write-module-bundle s
                                             verbose? modules config? literal-files literal-expressions collects-dest
                                             on-extension
                                             (file-name-from-path dest)
                                             compiler
                                             expand-namespace
                                             src-filter
                                             get-extra-imports))])
              (let-values ([(start end)
                            (if (and (eq? (system-type) 'macosx)
                                     (not unix-starter?))
                                ;; For Mach-O, we know how to add a proper segment
                                (let ([s (open-output-bytes)])
                                  (write-module s)
                                  (let ([s (get-output-bytes s)])
                                    (let ([start (add-plt-segment dest-exe s)])
                                      (values start
                                              (+ start (bytes-length s))))))
                                ;; Other platforms: just add to the end of the file:
                                (let ([start (file-size dest-exe)])
                                  (call-with-output-file* dest-exe write-module 
                                                          #:exists 'append)
                                  (values start (file-size dest-exe))))])
                (when verbose?
                  (fprintf (current-error-port) "Setting command line\n"))
                (let ([start-s (number->string start)]
                      [end-s (number->string end)])
                  (let ([full-cmdline (append
                                       (if launcher?
                                           (if (and (eq? 'windows (system-type))
                                                    keep-exe?)
                                               ;; argv[0] replacement:
                                               (list (path->string 
                                                      (if relative?
                                                          (relativize exe dest-exe values)
                                                          exe)))
                                               ;; No argv[0]:
                                               null)
                                           (list "-k" start-s end-s))
                                       cmdline)])
                    (when collects-path-bytes
                      (when verbose?
                        (fprintf (current-error-port) "Setting collection path\n"))
                      (set-collects-path dest-exe collects-path-bytes))
                    (cond
                      [(and use-starter-info? osx?)
                       (finish-osx-mred dest full-cmdline exe keep-exe? relative?)]
                      [unix-starter?
                       (let ([numpos (with-input-from-file dest-exe 
                                       (lambda () (find-cmdline 
                                                   "configuration"
                                                   #"cOnFiG:")))]
                             [typepos (and (or mred? (eq? variant '3m))
                                           (with-input-from-file dest-exe 
                                             (lambda () (find-cmdline 
                                                         "exeuctable type"
                                                         #"bINARy tYPe:"))))]
                             [cmdline
                              (apply bytes-append
                                     (map (lambda (s)
                                            (bytes-append 
                                             (cond
                                               [(path? s) (path->bytes s)]
                                               [else (string->bytes/locale s)])
                                             #"\0"))
                                          (append
                                           (list (if relative?
                                                     (relativize exe dest-exe values)
                                                     exe)
                                                 (let ([dir (find-dll-dir)])
                                                   (if dir
                                                       (if relative?
                                                           (relativize dir dest-exe values)
                                                           dir)
                                                       "")))
                                           full-cmdline)))]
                             [out (open-output-file dest-exe #:exists 'update)])
                         (let ([cmdline-end (+ end (bytes-length cmdline))]
                               [write-num (lambda (n)
                                            (write-bytes (integer->integer-bytes n 4 #t #f) out))])
                           (dynamic-wind
                            void
                            (lambda ()
                              (when typepos
                                (when mred?
                                  (file-position out (+ typepos 13))
                                  (write-bytes #"r" out))
                                (when (eq? variant '3m)
                                  (file-position out (+ typepos 15))
                                  (write-bytes #"3" out))
                                (flush-output out))
                              (file-position out (+ numpos 7))
                              (write-bytes #"!" out)
                              (write-num start)
                              (write-num end)
                              (write-num cmdline-end)
                              (write-num (length full-cmdline))
                              (write-num (if mred? 1 0))
                              (flush-output out)
                              (file-position out end)
                              (write-bytes cmdline out)
                              (flush-output out))
                            (lambda ()
                              (close-output-port out)))))]
                      [else
                       (let ([cmdpos (with-input-from-file dest-exe 
                                       (lambda () (find-cmdline 
                                                   "cmdline"
                                                   #"\\[Replace me for EXE hack")))]
                             [anotherpos (and mred?
                                              (eq? 'windows (system-type))
                                              (let ([m (assq 'single-instance? aux)])
                                                (and m (not (cdr m))))
                                              (with-input-from-file dest-exe 
                                                (lambda () (find-cmdline 
                                                            "instance-check"
                                                            #"yes, please check for another"))))]
                             [out (open-output-file dest-exe #:exists 'update)])
                         (dynamic-wind
                          void
                          (lambda ()
                            (when anotherpos
                              (file-position out anotherpos)
                              (write-bytes #"no," out))
                            (if long-cmdline?
                                ;; write cmdline at end:
                                (file-position out end)
                                (begin
                                  ;; write (short) cmdline in the normal position:
                                  (file-position out cmdpos)
                                  (display "!" out)))
                            (for-each
                             (lambda (s)
                               (fprintf out "~a~a~c"
                                        (integer->integer-bytes 
                                         (add1 (bytes-length (string->bytes/utf-8 s)) )
                                         4 #t #f)
                                        s
                                        #\000))
                             full-cmdline)
                            (display "\0\0\0\0" out)
                            (when long-cmdline?
                              ;; cmdline written at the end;
                              ;; now put forwarding information at the normal cmdline pos
                              (let ([new-end (file-position out)])
                                (file-position out cmdpos)
                                (fprintf out "~a...~a~a"
                                         (if keep-exe? "*" "?")
                                         (integer->integer-bytes end 4 #t #f)
                                         (integer->integer-bytes (- new-end end) 4 #t #f)))))
                          (lambda ()
                            (close-output-port out)))
                         (let ([m (and (eq? 'windows (system-type))
                                       (assq 'ico aux))])
                           (when m
                             (install-icon dest-exe (cdr m))))
                         (let ([m (and (eq? 'windows (system-type))
                                       (assq 'subsystem aux))])
                           (when m
                             (set-subsystem dest-exe (cdr m)))))])))))))))
    
    ;; For Mac OS X GRacket, the actual executable is deep inside the
    ;;  nominal executable bundle
    (define (mac-mred-collects-path-adjust p)
      (cond
        [(not p) #f]
        [(list? p) (map mac-mred-collects-path-adjust p)]
        [(relative-path? p) (build-path 'up 'up 'up p)]
        [else p]))))

