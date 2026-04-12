;; SPDX-License-Identifier: PMPL-1.0-or-later
;; minikanren-core.scm - MicroKanren implementation for Guile Scheme
;;
;; "MiniKanren does not solve your repo - it reveals what your repo refuses to admit."
;; - Voletaire

(define-module (scaffoldia constraints minikanren-core)
  #:export (var var? var=?
            walk walk*
            unify
            empty-state
            call/fresh
            disj conj
            ==
            run run*
            conde fresh
            membero appendo))

;; ============================================================
;; Logic Variables
;; ============================================================

;; A logic variable is represented as a vector with a unique index
(define (var idx) (vector idx))
(define (var? x) (vector? x))
(define (var=? x y) (= (vector-ref x 0) (vector-ref y 0)))

;; ============================================================
;; Substitution (the state)
;; ============================================================

;; A substitution is an association list mapping variables to values
;; The state is a pair: (substitution . next-var-index)

(define empty-state '(() . 0))

(define (state-subst state) (car state))
(define (state-counter state) (cdr state))

;; Walk: follow the chain of bindings to find the value of a variable
(define (walk term subst)
  (cond
    ((and (var? term) (assoc term subst var=?))
     => (lambda (binding) (walk (cdr binding) subst)))
    (else term)))

;; Deep walk: recursively walk through pairs
(define (walk* term subst)
  (let ((term (walk term subst)))
    (cond
      ((var? term) term)
      ((pair? term)
       (cons (walk* (car term) subst)
             (walk* (cdr term) subst)))
      (else term))))

;; Extend substitution with a new binding
(define (extend-subst var val subst)
  (cons (cons var val) subst))

;; ============================================================
;; Unification
;; ============================================================

;; Unify two terms, returning extended substitution or #f on failure
(define (unify term1 term2 subst)
  (let ((term1 (walk term1 subst))
        (term2 (walk term2 subst)))
    (cond
      ;; Both are the same variable
      ((and (var? term1) (var? term2) (var=? term1 term2))
       subst)
      ;; term1 is a variable - bind it
      ((var? term1)
       (extend-subst term1 term2 subst))
      ;; term2 is a variable - bind it
      ((var? term2)
       (extend-subst term2 term1 subst))
      ;; Both are pairs - unify recursively
      ((and (pair? term1) (pair? term2))
       (let ((subst (unify (car term1) (car term2) subst)))
         (and subst (unify (cdr term1) (cdr term2) subst))))
      ;; Both are equal atoms
      ((equal? term1 term2)
       subst)
      ;; Unification failed
      (else #f))))

;; ============================================================
;; Goals and Streams
;; ============================================================

;; A goal is a function that takes a state and returns a stream of states
;; A stream is either:
;;   - '() (empty)
;;   - (cons state stream) (mature)
;;   - (lambda () stream) (immature/suspended)

;; Suspend computation (for infinite streams)
(define-syntax zzz
  (syntax-rules ()
    ((_ goal) (lambda (state) (lambda () (goal state))))))

;; Equality goal: unify two terms
(define (== term1 term2)
  (lambda (state)
    (let ((subst (unify term1 term2 (state-subst state))))
      (if subst
          (list (cons subst (state-counter state)))
          '()))))

;; Introduce a fresh variable
(define (call/fresh f)
  (lambda (state)
    (let ((idx (state-counter state)))
      ((f (var idx))
       (cons (state-subst state) (+ idx 1))))))

;; Disjunction (or): interleave two streams
(define (disj goal1 goal2)
  (lambda (state)
    (mplus (goal1 state) (goal2 state))))

;; Conjunction (and): bind two goals
(define (conj goal1 goal2)
  (lambda (state)
    (bind (goal1 state) goal2)))

;; Interleave two streams (fair scheduling)
(define (mplus stream1 stream2)
  (cond
    ((null? stream1) stream2)
    ((procedure? stream1)
     (lambda () (mplus stream2 (stream1))))
    (else
     (cons (car stream1)
           (mplus (cdr stream1) stream2)))))

;; Apply goal to each state in stream
(define (bind stream goal)
  (cond
    ((null? stream) '())
    ((procedure? stream)
     (lambda () (bind (stream) goal)))
    (else
     (mplus (goal (car stream))
            (bind (cdr stream) goal)))))

;; ============================================================
;; User-level macros
;; ============================================================

;; conde: disjunctive normal form
(define-syntax conde
  (syntax-rules ()
    ((_ (goal ...) ...)
     (disj* (conj* goal ...) ...))))

(define-syntax disj*
  (syntax-rules ()
    ((_ goal) goal)
    ((_ goal0 goal1 goal ...)
     (disj (zzz goal0) (disj* goal1 goal ...)))))

(define-syntax conj*
  (syntax-rules ()
    ((_ goal) goal)
    ((_ goal0 goal1 goal ...)
     (conj goal0 (conj* goal1 goal ...)))))

;; fresh: introduce multiple fresh variables
(define-syntax fresh
  (syntax-rules ()
    ((_ () goal0 goal ...)
     (conj* goal0 goal ...))
    ((_ (x0 x ...) goal0 goal ...)
     (call/fresh
       (lambda (x0)
         (fresh (x ...) goal0 goal ...))))))

;; ============================================================
;; Running queries
;; ============================================================

;; Pull n results from a stream (or all if n is #f)
(define (take n stream)
  (cond
    ((and n (zero? n)) '())
    ((null? stream) '())
    ((procedure? stream) (take n (stream)))
    (else
     (cons (car stream)
           (take (and n (- n 1)) (cdr stream))))))

;; Reify a term: make it human-readable
(define (reify-name n)
  (string->symbol (string-append "_." (number->string n))))

(define (reify term state)
  (let ((term (walk* term (state-subst state))))
    (let ((reified-subst (reify-subst term '())))
      (walk* term reified-subst))))

(define (reify-subst term subst)
  (let ((term (walk term subst)))
    (cond
      ((var? term)
       (let ((n (length subst)))
         (extend-subst term (reify-name n) subst)))
      ((pair? term)
       (reify-subst (cdr term)
                    (reify-subst (car term) subst)))
      (else subst))))

;; run: execute a query and return n results
(define-syntax run
  (syntax-rules ()
    ((_ n (x ...) goal0 goal ...)
     (let ((results
            (take n
                  ((fresh (x ...) goal0 goal ...)
                   empty-state))))
       (map (lambda (state)
              (reify (list x ...) state))
            results)))))

;; run*: execute a query and return all results
(define-syntax run*
  (syntax-rules ()
    ((_ (x ...) goal0 goal ...)
     (run #f (x ...) goal0 goal ...))))

;; ============================================================
;; Common relations
;; ============================================================

;; membero: x is a member of list l
(define (membero x l)
  (fresh (head tail)
    (conde
      ((== l (cons x tail)))
      ((== l (cons head tail))
       (membero x tail)))))

;; appendo: l1 ++ l2 = l3
(define (appendo l1 l2 l3)
  (conde
    ((== l1 '()) (== l2 l3))
    ((fresh (head tail result)
       (== l1 (cons head tail))
       (== l3 (cons head result))
       (appendo tail l2 result)))))

;; ============================================================
;; Scaffoldia-specific helpers
;; ============================================================

;; Check if a symbol is in a list (for language detection)
(define (containso lst elem)
  (membero elem lst))

;; Relationship between two items (for constraints)
(define (relateso subject relation object)
  (== (list subject relation object) (list subject relation object)))
