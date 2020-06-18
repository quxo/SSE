# **This repo has moved to [https://gitlab.com/oquijano/sse](https://gitlab.com/oquijano/sse)**

# Server Sent Events Library for Racket
----

This is an implementation of server sent events (SSE) for
racket. An explanations of SSE's can be found in this [MDN web
doc](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events).

I was not able to use servlets to implement it since they return a
http response for each request. I did not find a way to use them to
create a stream. So, I wrote the http server from scratch largely
based on [Systems Programming with
Racket](https://docs.racket-lang.org/more/) by Matthew Flatt.

## Installation

In order to install this package clone the repository, enter the
cloned folder and run the following command

```bash
raco pkg install
```
## Example of use

The following code creates a page with a textarea that will be filled
with the `data` field of events. The page can be accessed through the
port 8080. The ECMAScript in the page connects to the port 8122 to get
server sent events. Each time that an event is sent it is added to the
textarea.

Save the following script in a file `sse_test.rkt`.

```racket
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
```

Now go to the same folder where you saved the file and run the racket
REPL. Then write

```racket
,enter "sse_test.rkt"
```

This starts the page servlet and the SSE server. Now, open your browser
and go to the url `localhost:8080`. You are going to see a welcome
message and an empty textarea. In order to add some text send a data
only event as follows:

```racket
(send-new-event a-sse #:data "Hello World!")
```

At this point the text "Hello World!" appears in the text area.

Now open a new tab or window of your browser and go again to
`localhost:8080`. Note that the message "Hello World!" does not appear
in this window. This is because we used `#:id` with value `#f` \(it is
the default value\). Let us now send one with `#:id` equal to `#t`.

```racket
(send-new-event a-sse #:data "Hello World! (again)" #:id #t)
```

At this point the two windows that you have open will show the messahe
"Hello World! \(again\)". This would be the case even with `#:id` equal
to `#f`. What makes the difference is that if you open now a new tab and
connect to `localhost:8080`, that window will also show this message.
