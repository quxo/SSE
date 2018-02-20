#lang racket

(require net/head)
(provide start-sse-tcp-port make-sse)
(provide (struct-out sse))
(provide send-new-event)


;; (provide (contract-out
;; 	  [send-event (-> (or/c sse? thread?) message?  void?)]))




(struct sse (sse-thread  [connection-threads #:mutable] messages-hash ))

(struct message (event data retry)) 

;; messages hash will store continuations containing the messages
  ;; The hash table has an entry last-message-id, which returns
  



(define (make-sse)
  (define self-sse
    (sse
     (thread (lambda ()
	       (let loop ()
		 (match (thread-receive)
		   [(? string? message) ;; if it is a message
;;; Get rid of finished threads		     
		    (set-sse-connection-threads!
		     self-sse
		     (filter thread-running? (sse-connection-threads self-sse ) ))
;;; Send the message to all threads
		    (map (lambda (x)
			   (thread-send x message)) (sse-connection-threads self-sse )  )]
		   [(? thread? t)		     
		    (set-sse-connection-threads!
		     self-sse
		     (append (sse-connection-threads self-sse ) (list t) ))])
		 (loop)
		 
		 )))
     empty
     (make-hash)
     ))

  (hash-set! (sse-messages-hash self-sse)
	     'last-message-id 0)
  
  self-sse)



(define (send-event to a-message [id #f])
  ;;  to can be a sse in which case the event is sent to all the
  ;;  instances, or, it can be a specific thread in which case the
  ;;  message is only send to that case.
  (define dest-thread
    (if (sse? to) (sse-sse-thread to) to))
    
  (when id
    (format "id: ~a\n" id))
  
  (define event (message-event a-message) )
  (define data  (message-data a-message) )
  (define retry  (message-retry a-message) )
  (thread-send dest-thread	       
	       (string-append
		(if (not (null? event))
		    (format "event: ~a\n" event )
		    ""
		    )

		(if (not (null? data))
		    (string-append
		     (apply string-append
			    (map (lambda (x)
				   (format "data: ~a\n" x))		      
				 (string-split data "\n"))) 
		     "\n") "")

		(if (not (null? retry))
		    (format "retry: ~a\n" retry )
		    "") 
		
		"\n") ))

(define (send-new-event a-sse
			#:data [data empty]
			#:event [event empty]
			#:id [id #f]
			#:retry [retry empty])

  (define a-message (message event data retry))

  (if id      
    (let ([ next-id  (add1 (hash-ref (sse-messages-hash a-sse) 'last-message-id))])			
      (hash-set! (sse-messages-hash a-sse)  'last-message-id next-id )	  
      (hash-set! (sse-messages-hash a-sse) next-id a-message )
      (send-event a-sse a-message next-id))
    (send-event a-sse a-message)
    ))




;; (define (send-event a-sse		    
;; 		    #:data [data empty]
;; 		    #:event [event empty]
;; 		    #:id [id #f]
;; 		    #:retry [retry empty])
  
;;   (thread-send (sse-sse-thread a-sse)
	       
;; 	       (string-append
		
;; 		(if  id
;; 		     (begin
;; 		       (let ([ next-id  (add1 (hash-ref (sse-messages-hash a-sse) 'last-message-id))])			
;; 			 (hash-set! (sse-messages-hash a-sse)  'last-message-id next-id )
;; 			 (let/cc k
;; 				 (hash-set! (sse-messages-hash a-sse) next-id k))
;; 			 (format "id: ~a\n" next-id)))
;; 		     "")		
		

;; 		(if (not (null? event))
;; 		    (format "event: ~a\n" event )
;; 		    ""
;; 		    )

;; 		(if (not (null? data))
;; 		    (string-append
;; 		     (apply string-append
;; 			    (map (lambda (x)
;; 				   (format "data: ~a\n" x))		      
;; 				 (string-split data "\n"))) 
;; 		     "\n")
;; 		    "\n")
		
;; 		)))


(module+ test
  (require rackunit)

  (define-values (in1 out1) (make-pipe))
  
  
  (define sse1 (make-sse))
  
  (define message-thread1 (thread (lambda ()
				    (let loop ()
				      (displayln (format "Thread 1: ~a"(thread-receive)) out1)
				      (loop)))))

  (define message-thread2 (thread (lambda ()
				    (let loop ()
				      (displayln (format "Thread 2: ~a"(thread-receive)) out1)
				      (loop)))))
  
  
  (check-equal? (sse-connection-threads sse1)  empty "Empty list check")
  
  (thread-send (sse-sse-thread sse1)  message-thread1)
  
  
  
  (thread-send (sse-sse-thread sse1 )  "Mensaje 1" )
  (check-equal? (read-line in1)  "Thread 1: Mensaje 1" "Check a message sent by a working thread" )

  (thread-send (sse-sse-thread sse1)  message-thread2)

  (thread-send (sse-sse-thread sse1 )  "Mensaje 2" )
  (check-equal? (read-line in1)  "Thread 2: Mensaje 2" "Check a message sent by a working thread" )
  (check-equal? (read-line in1)  "Thread 1: Mensaje 2" "Check a message sent by a working thread" )

  (kill-thread message-thread1)

  (thread-send (sse-sse-thread sse1 )  "Mensaje 3" )
  (check-equal? (read-line in1)  "Thread 2: Mensaje 3" "Check a message sent by a working thread" )
  
  )


(define (start-sse-tcp-port port-no a-sse)    
  (define main-custodian (make-custodian))
  (parameterize ([current-custodian main-custodian])
    (define listener (tcp-listen port-no))
    (define (loop)	
      (accept-and-handle listener a-sse)	
      (loop))      
    (thread loop)
    )

  (lambda ()
    (custodian-shutdown-all main-custodian)))


(define (accept-and-handle listener a-sse)
  
  (define cust (make-custodian))
  (parameterize ([current-custodian cust])
    
    (define-values (in out ) (tcp-accept listener))
    (thread-send (sse-sse-thread a-sse)
		 (thread (lambda ()
			   (handle in out a-sse)
			   (close-input-port in)
			   (close-output-port out))))))



(define (read-header in)
  (read-line in)
  (define (auxf [accum ""] [cur-line (read-line in 'any) ])
    (if (or (equal? cur-line "\r") (equal? cur-line ""))
	(string-append  accum "\r\n")
	(auxf (string-append accum  cur-line "\n") (read-line in) ))
    )
  (auxf)
  )

(define (handle in out a-sse)
  
  ;; (define current-request
  ;;   (let loop ([accum ""]
  ;; 	       [cur-line (read-line in 'any)])
  ;;     (if (or (equal? cur-line "\r") (equal? cur-line ""))
  ;; 	  accum
  ;; 	  (loop (string-append accum cur-line) (read-line in) ))))

  (define current-request (read-header in))
   

  (when (string>? current-request "")
    (display "HTTP/1.0 200 Okay\r\n" out)
    (display "Access-Control-Allow-Origin: *\r\n" out)
    (display "Cache-Control: no-cache\r\n"  out)
    (display "Server: k\r\nContent-Type: text/event-stream\r\n\r\n" out)
    (flush-output out)

    ;; The following is the last id received by the client
    (define last-received-event-id
      (or  (extract-field "Last-Event-ID" current-request ) 0))

    (define last-event-id
      (hash-ref (sse-messages-hash a-sse) 'last-message-id))

    (when (and last-received-event-id (> last-event-id last-received-event-id))
      (for ([i (in-range (add1 last-received-event-id) (add1 last-event-id) )])
	(send-event (current-thread)
		    (hash-ref (sse-messages-hash a-sse) i) )))
            
    
    (let loop ()
      (display (format "~a" (thread-receive)) out)
      (flush-output out)
      (loop))
    
    ))



