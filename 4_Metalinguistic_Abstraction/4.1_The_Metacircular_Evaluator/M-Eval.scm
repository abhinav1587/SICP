(define true #t)

(define false #f)

(define (true? x)
  (not (eq? x #f)))

(define (false? x)
  (eq? x #f))

(define (cond? exp) (tagged-list? exp 'cond))

(define (cond-clauses exp) (cdr exp))

(define (cond-predicate clause) (car clause))

(define (cond-else-clause? clause)
  (eq? (cond-predicate clause) 'else))

(define (cond-actions clause) (cdr clause))

(define (make-begin seq) (cons 'begin seq))

(define (begin? exp) (tagged-list? exp 'begin))

(define (begin-actions exp) (cdr exp))

(define (last-exp? seq) (null? (cdr seq)))

(define (first-exp seq) (car seq))

(define (rest-exps seq) (cdr seq))

(define (sequence->exp seq)
  (cond ((null? seq) seq)
	((last-exp? seq) (first-exp seq))
	(else (make-begin seq))))

(define (expand-clauses clauses)
  (if (null? clauses)
      'false                          ; no `else' clause
      (let ((first (car clauses))
	    (rest (cdr clauses)))
	(if (cond-else-clause? first)
	    (if (null? rest)
		(sequence->exp (cond-actions first))
		(error "ELSE clause isn't last -- COND->IF"
		       clauses))
	    (make-if (cond-predicate first)
		     (sequence->exp (cond-actions first))
		     (expand-clauses rest))))))

(define (cond->if exp)
  (expand-clauses (cond-clauses exp)))

(define (application? exp)
  (pair? exp))

(define (operator exp) (car exp))

(define (operands exp) (cdr exp))

(define (no-operands? ops) (null? ops))

(define (first-operand ops) (car ops))

(define (rest-operands ops) (cdr ops))

(define (make-if predicate consequent alternative)
  (list 'if predicate consequent alternative))

(define (if? exp) (tagged-list? exp 'if))

(define (if-predicate exp) (cadr exp))

(define (if-consequent exp) (caddr exp))

(define (if-alternative exp)
  (if (not (null? (cdddr exp)))
      (cadddr exp)
      'false))

(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))

(define (lambda? exp) (tagged-list? exp 'lambda))

(define (lambda-parameters exp) (cadr exp))

(define (lambda-body exp) (cddr exp))

(define (definition-value exp)
  (if (symbol? (cadr exp))
      (caddr exp)
      (make-lambda (cdadr exp)   ; formal parameters
		   (cddr exp)))) ; body

(define (definition-variable exp)
  (if (symbol? (cadr exp))
      (cadr exp)
      (caadr exp)))

(define (definition? exp)
  (tagged-list? exp 'define))

(define (assignment-value exp) (caddr exp))

(define (assignment-variable exp) (cadr exp))

(define (assignment? exp)
  (tagged-list? exp 'set!))

(define (tagged-list? exp tag)
  (if (pair? exp)
      (eq? (car exp) tag)
      false))

(define (text-of-quotation exp) (cadr exp))

(define (quoted? exp)
  (tagged-list? exp 'quote))

(define (variable? exp)
  (symbol? exp))

(define (self-evaluating? exp)
  (cond ((number? exp) true)
	((string? exp) true)
	(else false)))

;;; Operations on Environments

(define (enclosing-environment env) (cdr env))

(define (first-frame env) (car env))

(define the-empty-environment '())

(define (make-frame variables values)
  (cons variables values))

(define (frame-variables frame) (car frame))

(define (frame-values frame) (cdr frame))

(define (add-binding-to-frame! var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(define (extend-environment vars vals base-env)
  (if (= (length vars) (length vals))
      (cons (make-frame vars vals) base-env)
      (if (< (length vars) (length vals))
	  (error "Too many arguments supplied" vars vals)
	  (error "Too few arguments supplied" vars vals))))

(define (lookup-variable-value var env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
	     (env-loop (enclosing-environment env)))
	    ((and (eq? var (car vars))
		  (eq? (car vals) '*unassigned*))
	     (error "Unassigned variable" var))
	    ((eq? var (car vars))
	     (car vals))
	    (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
	(error "Unbound variable" var)
	(let ((frame (first-frame env)))
	  (scan (frame-variables frame)
		(frame-values frame)))))
  (env-loop env))

(define (set-variable-value! var val env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
	     (env-loop (enclosing-environment env)))
	    ((eq? var (car vars))
	     (set-car! vals val))
	    (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
	(error "Unbound variable -- SET!" var)
	(let ((frame (first-frame env)))
	  (scan (frame-variables frame)
		(frame-values frame)))))
  (env-loop env))

(define (define-variable! var val env)
  (let ((frame (first-frame env)))
    (define (scan vars vals)
      (cond ((null? vars)
	     (add-binding-to-frame! var val frame))
	    ((eq? var (car vars))
	     (set-car! vals val))
	    (else (scan (cdr vars) (cdr vals)))))
    (scan (frame-variables frame)
	  (frame-values frame))))

(define (eval-definition exp env)
  (define-variable! (definition-variable exp)
    (eval (definition-value exp) env)
    env)
  'ok)

(define (eval-assignment exp env)
  (set-variable-value! (assignment-variable exp)
		       (eval (assignment-value exp) env)
		       env)
  'ok)

(define (eval-sequence exps env)
  (cond ((last-exp? exps) (eval (first-exp exps) env))
	(else (eval (first-exp exps) env)
	      (eval-sequence (rest-exps exps) env))))

(define (eval-if exp env)
  (if (true? (eval (if-predicate exp) env))
      (eval (if-consequent exp) env)
      (eval (if-alternative exp) env)))

(define (list-of-values exps env)
  (if (no-operands? exps)
      '()
      (cons (eval (first-operand exps) env)
	    (list-of-values (rest-operands exps) env))))

(define (make-procedure parameters body env)
  (list 'procedure parameters (scan-out-defines body) env))

(define (compound-procedure? p)
  (tagged-list? p 'procedure))

(define (procedure-parameters p) (cadr p))

(define (procedure-body p) (caddr p))

(define (procedure-environment p) (cadddr p))


;;; Evaluator

(define (eval exp env)
  (cond ((self-evaluating? exp)
	 exp)
	((let? exp)
	 (eval (let->combination exp) env))
	((variable? exp)
	 (lookup-variable-value exp env))
	((quoted? exp)
	 (text-of-quotation exp))
	((assignment? exp)
	 (eval-assignment exp env))
	((definition? exp)
	 (eval-definition exp env))
	((if? exp)
	 (eval-if exp env))
	((lambda? exp)
	 (make-procedure (lambda-parameters exp)
			 (lambda-body exp)
			 env))
	((begin? exp)
	 (eval-sequence (begin-actions exp) env))
	((cond? exp)
	 (eval (cond->if exp) env))
	((application? exp)
	 (apply (eval (operator exp) env)
		(list-of-values (operands exp) env)))
	(else
	 (error "Unknown expression type -- EVAL" exp))))


;;; Do not re evaluate this procedure twice in the
;;; same session. Doing this twice breaks the interpreter
;;; (define apply-in-underlying-scheme apply)

(define (primitive-procedure? proc)
  (tagged-list? proc 'primitive))

(define (primitive-implementation proc)
  (if (procedure? proc)
      proc
      (cadr proc)))

(define (apply-primitive-procedure proc args)
  (if (eq? 1 (procedure-minimum-arity proc))
      (proc args)
      (apply-in-underlying-scheme
       (primitive-implementation proc) args)))

(define (apply procedure arguments)
  (cond ((or (procedure? procedure) (primitive-procedure? procedure))
	 (apply-primitive-procedure procedure arguments))
	((compound-procedure? procedure)
	 (newline)
	 (eval-sequence
	  (procedure-body procedure)
	  (extend-environment
	   (procedure-parameters procedure)
	   arguments
	   (procedure-environment procedure))))
	(else
	 (error
	  "Unknown procedure type -- APPLY" procedure))))

;;; Running the Evaluator

(define primitive-procedures
  (list (list 'car car)
	(list 'cdr cdr)
	(list 'cons cons)
	(list 'null? null?)
	(list '= =)
	(list '* *)
	(list '+ +)
	(list '- -)))

(define (primitive-procedure-names)
  (map car
       primitive-procedures))

(define (primitive-procedure-objects)
  (map (lambda (proc) (list 'primitive (cadr proc)))
       primitive-procedures))

(define (setup-environment)
  (let ((initial-env
	 (extend-environment (primitive-procedure-names)
			     (primitive-procedure-objects)
			     the-empty-environment)))
    (define-variable! 'true true initial-env)
    (define-variable! 'false false initial-env)
    initial-env))

(define the-global-environment (setup-environment))

;;; let combinations

(define (let? exp)
  (tagged-list? exp 'let))

(define (let-expression-definitions exp)
  (cadr exp))

(define (let-body exp)
  (cddr exp))

(define (let-vars expression-definitions)
  (cond ((null? expression-definitions) '())
	(else (cons (caar expression-definitions)
	       (let-vars (cdr expression-definitions))))))

(define (let-exprs expression-definitions)
  (cond ((null? expression-definitions) '())
	(else (cons (cadar expression-definitions)
	       (let-exprs (cdr expression-definitions))))))

(define (let->combination exp)
  (cons
   (cons
    'lambda
    (cons
     (let-vars (let-expression-definitions exp))
     (let-body exp)))
   (let-exprs (let-expression-definitions exp))))


;;; scan out defines

(define (scan-out-defines p-body)
  (if (not (null? (procedure-variable-body-mapping p-body)))
      (list
       (let->combination
	(append
	 (list
	  'let
	  (procedure-defines-unassigned
	   (procedure-defines
	    (procedure-variable-body-mapping p-body))))
	 (append
	  (procedure-assignment
	   (procedure-variable-body-mapping p-body))
	  (procedure-expressions p-body)))))
      p-body))

(define (procedure-expressions p-body)
  (cond ((null? p-body) '())
	((definition? (car p-body))
	 (procedure-expressions (cdr p-body)))
	(else p-body)))

(define (procedure-variable-body-mapping p-body)
  (cond ((null? p-body) '())
	((definition? (car p-body))
	 (cons (list
		(definition-variable (car p-body))
		(definition-value (car p-body)))
	       (procedure-variable-body-mapping (cdr p-body))))
	(else '())))

(define (procedure-defines mapping)
  (cond ((null? mapping) '())
	(else (cons
	       (caar mapping)
	       (procedure-defines (cdr mapping))))))

(define (procedure-defines-unassigned defines)
  (cond ((null? defines) '())
	(else (cons
	       (list (car defines) ''*unassigned*)
	       (procedure-defines-unassigned (cdr defines))))))

(define (procedure-bodies mapping)
  (cond ((null? mapping) '())
	(else (cons
	       (cadar mapping)
	       (procedure-bodies (cdr mapping))))))

(define (procedure-assignment mapping)
  (cond ((null? mapping) '())
	(else
	 (cons (list
		'set!
		(car (procedure-defines mapping))
		(car (procedure-bodies mapping)))
	       (procedure-assignment (cdr mapping))))))
