#lang scribble/manual

@require[@for-label[SSE
                    racket/base]]

@title{SSE}
@author{Oscar Alberto Quijano Xacur}

@defmodule[SSE]

@section{Provided definitions}


The events stream is defined with a struct:

@defstruct[sse ([sse-thread thread?] [connection-threads (listof thread?)] [messages-hash hash?] )
#:omit-constructor]{
@itemlist[
	@item{@racket[sse-thread] is the thread with the running SSE
	source}
	@item{@racket[connection-threads] is a list contaning the
	threads of the active connections}
	@item{@racket[messages-hash] is a hash table containing the
	messages with non-false #:id }]
	}

@defproc[(make-sse)  sse?]{Creates a new event stream.}


@defproc[(start-sse-tcp-port
	[port-no positive-integer?]
	[a-sse sse?]
	[max-allow-wait exact-nonnegative-integer? 4]
	[reuse? boolean? #f]
	[hostname (or/c string? #f) #f]
	)
	procedure?]{

Starts listening for connections on port @racket[port-no] and uses
@racket[a-sse] to send events. It returns a procedure that stops
listening once it is called. @racket[max-allow-wait], @racket[reuse?]
and @racket[hostname] are as in @racket[tcp-listen].

	}


As explained in this
@hyperlink["https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events"
"MDN web doc" ] an event has one or more of four possible fields:
@italic{id}, @italic{event}, @italic{data},
@italic{retry}. @racket[send-new-event] can be used to send an
event. It has keywords for the four possible fields.


@defproc[(send-new-event
	  [a-sse sse?]
	  [#:data data (or/c string? null?) empty]
	  [#:event event (or/c string? null?) empty]
	  [#:id id boolean? #f]
	  [#:retry retry (or/c positive-integer? null?) empty ])
	  void?]{
	  
	  If @racket[id] is @racket[#t] the message is send and it is
	  added to the @racket[message-hash] of @racket[a-sse]. The
	  actual @racket[id] value sent is always a positive integer
	  starting from one. It is automatically managed by the
	  library. The messages added to the @racket[message-hash] are
	  sent to new connections. When the header
	  @racket[Last-Event-ID] is sent in a request only the
	  messages with an @racket[id] greater than that value are sent.
	  
}	       

   
@section{Example of use}

The following code creates a page with a textarea that will be filled
with the @racket[data] field of events. The page can be accessed
through the port 8080. The ECMAScript in the page connects to the port
8122 to get server sent events. Each time that an event is sent it is
added to the textarea.

Save the following script in a file @racket[sse_test.rkt].

@codeblock|{
#lang racket

(require web-server/http/xexpr)
(require web-server/servlet-env)

(require SSE)

;; Page that connects to the server-sent events
(define (start-page req)
    (response/xexpr
	`(html
	  (head
	  (meta ([http-equiv "content-type"] [content "text/html; charset=utf-8"] ))
	  (meta ([name "viewport"] [content "width=device-width"] ))
	  (title "Events test"))

	  (body
	  (h1 "Welcome to the Events test")
	  (textarea ([readonly ""]))
	  (script
	  "
	  var evtSource = new EventSource(\"//localhost:8122\");
	  var textArea = document.getElementsByTagName(\"textarea\")[0];

	  evtSource.onmessage = function(e){
	      textArea.value =  e.data + \"\\n\" + textArea.value ;
	      console.log(e.data);
	  }
 	  ")))))

(define a-sse (make-sse))

(define (start-all)

  ; start the SSE listener
  (define sse-stop (start-sse-tcp-port 8122 a-sse))

  ; starts the page servlet
  (define page-thread  (thread
			(lambda ()
			  (serve/servlet start-page
					 #:launch-browser? #f
					 #:quit? #f
					 #:servlet-path "/"
					 #:port 8080))))
  
  ; return a function that stops the page servlet and the SSE listener
  (lambda ()
    (sse-stop)
    (kill-thread page-thread))
  )


(define stop-all (start-all))
}|


	       
Now go to the same folder where you saved the file and run the racket
REPL. Then write

@codeblock{,enter "sse_test.rkt"}

This starts the page servlet and the SSE server. Now, open your
browser and go to the url @racket[localhost:8080]. You are going to
see a welcome message and an empty textarea. In order to add some text
send a data only event as follows:

@codeblock{(send-new-event a-sse #:data "Hello World!")}

At this point the text "Hello World!" appears in the text area.

Now open a new tab or window of your browser and go again to
@racket[localhost:8080]. Note that the message "Hello World!" does not
appear in this window. This is because we used @racket[#:id] with
value @racket[#f] (it is the default value). Let us now send one with
@racket[#:id] equal to @racket[#t].

@codeblock{(send-new-event a-sse #:data "Hello World! (again)" #:id #t)}

At this point the two windows that you have open will show the messahe
"Hello World! (again)". This would be the case even with @racket[#:id]
equal to @racket[#f]. What makes the difference is that if you open
now a new tab and connect to @racket[localhost:8080], that window will
also show this message.

