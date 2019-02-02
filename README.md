# Web Utilities
Small utilities sometimes useful to web development. 

Beware that some of these may be old and or ugly, but they have the advantage of working for me. 

## cgibinIntercept.sh
cgi-bin debugging aid.

  Have a misbehaving cgi-bin? Wrote this tool long ago to assure developers always get useful information returned to them... no more 500 errors.

 * If the cgi-bin fails severely a diagnostic page is returned showing much details.
 * A log file is also created that logs both the input from the web browser and the output from the cgi-bin.

Stay within the limits and the program can be useful. 

Documentation is found within the script itself.

Restrictions:

 * Not intended for public systems as it lowers security by showing internals of web application.
 * Also only runs under POSIX compliant shells in Appache CGI-BIN envionments. 

Status: Old but still does its job.
