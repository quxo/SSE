#lang scribble/manual
@require[@for-label[SSE
                    racket/base]]

@title{SSE}
@author{Oscar Alberto Quijano Xacur}

@defmodule[SSE]


The events stream is defined with thought a struct:

@defstruct[sse ([sse-thread thread?] [connection-threads (listof
threads?)] [messages-hash hassh?] )]{
@itemlist[
	@item{@italic{sse-thread} is the thread with the running SSE
	source}
	@item{@italic{connection-threads} is a list contaning the
	threads of the active connections}
	@item{@italic{messages-hash} is a hash table containing the
	messages with non-false #:id}
]
}



@defproc[(make-sse)  sse?]{Creates a new event stream.}




As explained in this @hyperlink[
   "https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events"
   "MDN web doc" ] an event has one or more of four possible fields:
   @italic{id}, @italic{event}, @italic{data}, @italic{retry}. The
   last three are defined in the @racket['message] struct. 
   
@defstruct[message ([event string?] [data string?] [retry (positive-integer?)]) ]

