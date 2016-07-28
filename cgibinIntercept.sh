#!/usr/bin/env bash
#echo "Content-Type: text/plain";
#echo "";
#echo "Testing";
#
# NAME 
# 
#     cgibinIntercept -- intercept requests to execute cgi-bin programs.
# 
# SYNOPSIS
# 
#     http://www.yourserver.sample/cgi-bin/you-cgi-program
# 
#     cgibinIntercept --watch [uname]
# 		watch log file for changes
# 		    uname = id of log to find (e.g., nobody).
# 		    uses $apacheOwner as default user name if not found.
# 
#     With the exception of --watch, any run-time arguments to 
#     cgibinIntercept are passed directly on to the true cgi-bin program.
# 
# DESCRIPTION
# 
#     During development or debugging of cgi-bin programs, cgibinIntercept.sh
#     can be used instead of the suspect program. cgibinIntercept.sh 
#     runs the suspect program in a way that logs all output to log files 
#     rather than immediately returning it to the browser.  Much more 
#     metrics and checks for common problems are made available for 
#     debugging in the logs.
#
#     If the suspect program works without error, cgibinIntercept returns
#     the original output to the web browser and stderr to Apache's log file
#     as normal. Users are not aware of any difference in output, with perhaps
#     only a slightly longer response time.
#
#     If the suspect program has major errors, rather than returning an
#     obscure "500" error error text more useful to problem trackers
#     is returned. But see SECURITY ISSUES.
#
#     In all cases the log files are kept until future activity overwrites
#     them.
#
# INSTALLATION
# 
#     Two styles of installation are possible:
# 
#     #	Installing cgibinIntercept under the name of the true cgi-bin 
# 	program after renaming the true cgi-bin program to keep it available,
#       but not executed directly by Apache.  
#	   # the typical use is to rename foo to foo.orig (foo.pl > foo.pl.orig)
#	   # but the original program may be kept anywhere, including its
#	     native development tree if that's on the web server; any 
#	     changes to the working development tree become immediately 
#	     available without copying it to the official cgi-bin directory.
# 
#     #	Installing cgibinIntercept under a different, but often similar, 
#	name. The associated debugging and log capture only occurs on 
# 	explicit request. The name may be hidden from normal users.
# 
#     A configuration file (foo.cgiconf for foo) is set up to direct
#     cgibinIntercept.sh to the true cgi-bin program, along with performing
#     other configurations.
#
#     The LOCAL CONFIGURATION section in the code below has more details
#     on configuring cgibinIntercept. Recommend you use the .cgiconf
#     configuration file so you do not need to change this script.
# 
# EXAMPLE
#	cd cgi-bin
#	cp -p $Downloads/cgibinIntercept .
#	chmod 755 cgibinIntercept
#	mv suspect.pl suspect.pl.orig
#  	ln cgibinIntercept suspect.pl
#
#   If you STILL don't get any helpful output from the web server 
#   look in the temporary log files. By default in /tmp/. 
#
# RESTRICTIONS
# 
#     By default no attempt is made to prevent log files from two different 
#     requests to clash with each other. In fact, they will clash. This has 
#     been OK so far as cgibinIntercept is only intended for low-volume 
#     debugging of programs under development or, rarely, field debugging of
#     existing programs where hits can be controlled for a short period of time.
# 
#     The "clashControl" setting can be set to reduce the chances of log
#     file clashes (reduce). This is simply defines the number of log files
#     cgibinIntercept.sh is to rotate through. A lot of complex things could
#     be done to better handle log clashing, but in the limited debugging 
#     environments cgibinIntercept is used in, the current clash control has
#     proven sufficient. More exotic clash control might lead people to 
#     long-term use of cgibinIntercept on public web browsers, with 
#     corresponding security issues (see SECURITY ISSUES).
# 
# AUTHOR
# 
#       Gilbert Healton <ghealton@healton.net>
# 	or search the web for the exact phrase "Original Mad Programmer" (TM)
# 
# LICENSE
# 
#     Released under perl's Artistic License.
# 
# SECURITY ISSUES
#
#    The error reports from cgibinIntercept may make internal information 
#    available to hostile hackers available. All public uses must bear this
#    in mind.
#
#    The log files are effectively world readable allowing anyone with 
#    logins on the system to review their contents.
#
# DISCLAIMER
# 
#     THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
#     IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
#     WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 

VERSION='$Id: cgibinIntercept.sh,v 1.19 2004/09/19 04:34:37 gilbert Exp gilbert $';


######################################################################
#
#   LOCAL CONFIGURATION
#	# The following reflect items the local system administrator,
#	  or developer, installing cgibinIntercept is likely to change.
#	# rather than changing an existing line, simply add a new one,
#	  with the desired values, BELOW the sample line.
#
#    v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v 
#	# even better, don't change this at all... add a new file with the
#	  same name as your cgi-bin program, but add an extension
#	  of ".cgiconf". it will be read in and used. put your changes there.
#	   # your changes will be preserved across upgrades of cgibinIntercept.
#	   # program foo.pl would use foo.pl.cgiconf
#
### set up path to log file.
###	 very insecure if kept in /tmp. likely insecure WHEREVER it is kept.
logdir="/tmp";		#directory to write log files to due to
			##the fact it is "owned" by the web browser user

### path name to the program to be used
###   (if you rename your original program foo.pl to foo.pl.orig, the
###    following will work without change)
exe="$0.orig";
if [[ "$exe" != /* ]]; then
    #assure "/" in to bypass PATH search, which does not have "."
    exe="./$exe";
fi

#establish current user name by running shell command
logWho=`/usr/bin/id -un`;

#perl to use under clashControl
perl=`which perl`

### user name for local web server 
###  (e.g., user owning files created when Apache is running)
apacheOwner="nobody";

### log file clash control to (only) REDUCE chances of log file clashing... 
###	(only an ugly hack which improves things for this poor shell script)
clashControl=1; 	#maximum log files to keep. >= 2 enables clash control.
		# cgibinIntercept will rotate through this many log files.
		# The --watch option may miss the tail of log files once
		# a new log becomes available.

sleep=1;		#sleep time between polling


######################################################################
#
#   START OF MORE STABLE STUFF
#	# the following is not that likely to be changed by
#	  local administrators.
#
scriptbase=$( basename "${0}" | sed -e 's/  */_/'g -e 's/\.[a-z][a-z]$//' )

logPrefix="$logdir/${scriptbase}-";	#change directory to write log to
logSuffix=".log";
clashSuffix=".ctr";

lsopt="-t";		#ls args to list in order of date, youngest first

if [ -f $0.cgiconf ]; then
	source $0.cgiconf
    fi


######################################################################
#
#   START OF INTERNAL STUFF
#	# the following is likely only of interest to developers
#	  working directly on cgibinIntercept.sh rather than
#	  users of cgibinIntercept.sh
#

# type of file to return to web browser on fatal errors that otherwise
# prevent the cgi-bin being run from generating a Content-Type header.
Content_Type="Content-Type: text/html";


######################################################################
#
#   INTERNAL FUNCTIONS
#
watchSw=false;		#suppose normal cgi-bin executions

htmlOrTxt ()
{
    if $watchSw; then
	sed -e 's/<[^>]*>/g'
    else
    	cat
    fi
}


spew ()
{
    sed  -e 's/&/&amp/g' -e 's/</&lt;/g' -e 's/>/&gt;/g' "$1";
}

closeresponse ()
{
    cat >>"$log" <<EOF
---------- end   cgi-bin output ----------
lines: $linesout
EOF
}

carpStderr=false;	#set true after stderr copied to regular log
carp ()
{   #report errors to browser in ways the user of the browser can
    #actually read.
    # (put out oldest style HTML, that does not even need <HTML>....</HTML>)
    echo "$*" | htmlOrTxt >>"$log "
    
    if [ ."$Content_Type" != . ]; then
	    cat <<EOF
$Content_Type

<TITLE>$0 ERROR</TITLE>
EOF
	    Content_Type="";		#never again put headers
        fi

    cat <<EOF
<H1>ERROR IN $0</H1>
<H2>$*</H2>
This cgi-bin program $exec
failed to reply with valid Content-Type HTML header.
<P><STRONG>cgibinIntercept.sh</STRONG> has caught this problem to return 
an error message more useful than the "500 Server Error" 
you would have likely received.
<P>
The transcript of the session follows:</P>

<PRE>------ start log ------
EOF
    if [ -f "$log" ]; then
	spew "$log"
     else
     	echo "<no log file present>"
     fi
    cat <<EOF
------ end log ------</PRE>
EOF
    if ! $carpStderr && [ -s "$log".stderr ]; then
	cat <<EOF
<PRE>------ start stderr ------
EOF
	spew "$log".stderr
	cat <<EOF
------ end stderr ------</PRE>
lines: $( wc -l "$log".stderr | awk '/[0-9]/ {print $1}' )
EOF
      fi

    return;			#just notify of error, no death.
}

die ()
{   #report fatal error.
    xit=$1;
    shift;
    carp "$@";			#throw out messages
    echo "<P>Aborting page</P><P>" | htmlOrTxt;	#death rattle
    exit $xit;			#die an ugly death
}

# print lines of file starting with given line
#   $1  Line to start at.
#   $2  file to print
#  Avoid "tail" as it varies too much between different OSs
tailx ()
{
    awk -vskipx="${1#+}" ' { if ( ++n >= skipx ) print; }' "$2"
}


######################################################################


### check if running from command line to "--watch" log file
clashCode="";		#suppose no clashing wanted
clashError=0;		#becomes TRUE if fatal error prventing good log file
if [ ."$1" == ."--watch" ]; then
# {
	watchSw=true;
	logWho="$2";
	if [ ."$logWho" = ."" ]; then 
	    logWho="$apacheOwner";
	  fi 
	if [ $clashControl -ge 2 ]; then
	    clashCode='-*'
	  fi
	logx="$logPrefix$logWho$clashCode$logSuffix";
	log=$( ls $lsopt "$logx" 2>/dev/null | head -1 );
	if [ ."$log" = . ]; then
	# {
	      echo "CAN NOT FIND ANY LOG FILE UNDER $logx";
	      exit 1;
	# }
	  fi
# }
  else
# { 	# normal execution: log all output
	if [ $clashControl -ge 2 ]; then
		ctlFile="$logPrefix$logWho$clashSuffix";
		clashCode="$( 
		cat <<DUMMY >/dev/null
		    ### DUMMY BLOCK: "offline" stuff kept for reference
		    $perl -cw <<PERL 2>&1 
		    awk <<PERL 2>&1 '/./ { n = n + 1; print n, ": ", $0; }'
DUMMY
		$perl <<PERL 2>&1 
		    ## ugly perl intermediate program to increment 
		    ##  WITH DECENT LOCKS a unique counter for local log file
		    ## kept ugly to keep cgibinIntercept a shell script AND
		    ##  discourage anyone from believing this SOLVES all 
		    ##  log name clashing problems, even under a mythical
		    ##  cgibinIntercept.pl
		    use strict;
		    use FileHandle;
		    use Fcntl ':flock';
		    sub cry ($;$$$$) 
		    {   #return error text
			print join( " ", @_, );
			print "\\n";
			exit 1;
		    }
		    #\$LOCK_EX = 2 unless defined \$LOCK_EX;	#fail-safe
		    my \$LOCK_EX = LOCK_EX;
		    my \$ctr = 0;	#default log number
		    my \$fh = new FileHandle( "$ctlFile", "r+");
		    if ( \$fh )
		    {   #file opened for read/write
			flock( \$fh, \$LOCK_EX ) 
			  || cry "rwLockError: $ctlFile: \${LOCK_EX}: \$!\\n";
			my \$tmp = \$fh->getline;
			\$ctr = \$1 + 1 if \$tmp =~ /^(\\d+)/;
			\$ctr = \$ctr % $clashControl;
			seek(\$fh,0,0);
			truncate(\$fh, 0);
		    }
		    else
		    {
			\$fh = new FileHandle( "$ctlFile", "w" );
			if ( ! \$fh )
			{   #still no output
			    cry  "openError: $ctlFile: \$!\\n";
			}
			flock( \$fh, \$LOCK_EX ) 
				|| cry "woLockError: \${LOCK_EX}:  \$!\\n";
		    }
		    \$fh->print( "\$ctr\\n" );
		    \$fh->close;
		    print "\$ctr\\n";	#value to use to stdout
PERL
		      )";
	  	clashError=$?;		#remember if fatal error or not
		if [[ $clashError -ne 0  ||  \
			 	 ."$clashCode" != .[0-9]* ]]; then
			# cry exit (or other wildly undefined return)
			die 8 "$0 LOCK FILE ERROR. $clashCode";
		    fi
	  	clashCode="-$clashCode";	#add in prefix on success
	  fi
	log="$logPrefix$logWho$clashCode$logSuffix";
  fi
# }


#
#  start a new log file
#
if ! $watchSw; then
# { running as a cgi-bin program: start a clean log file
    err=$( date 2>&1 >"$log" "+%F %T: begin log for $exe" )
    if [ $? -ne 0 ]; then
	carp "CAN NOT CREATE STDOUT LOG FILE ($?): $log"
	echo "<P>error=$err</P>";
	exit 33;		#always use this exit on error
      fi
    echo >>"$log" "$VERSION"
    if [ -e "$log".stderr ]; then rm -f "$log".stderr; fi
    touch "$log".stderr;
    if [ $? -ne 0 ]; then
	carp "CAN NOT CREATE STDERR LOG FILE ($?): $log.stderr"
	exit 34;		#always use this exit on error
      fi
  fi
# }
#
#   test the executable we are to run
#
if [ ! -f $exe ]; then 
	ls -l $exe >> "$log" 2>&1;
	die 44 "NO FILE $exe";
	exit 44;		#fail-safe exit
   fi

if [ ! -x $exe ]; then 
	ls -l $exe >> "$log";
	die 55 "NOT EXECUTABLE $exe";
	exit 55;		#fail-safe exit
   fi
#
#   after all tests and initialization, process any --watch requests
#
if $watchSw; then
# {
    cnt=0;		#loop counter
    t="random string guaranteed not to match anything";
    logLast=".";		#if clashControl, use initial log
    while true; do
	if [ $clashControl -gt 1 ]; then
	# { #clashControl active: check if latest log file IS what we want
	    log=$( ls $lsopt "$logx" | head -1 ); #latest log file 
	    if [ ."$log" != ."$logLast" ]; then
		logLast="$log";
		t="switching log files forces new output";
		echo "       --- watching $log ---"
	      fi
	# }
	  fi
	n=`ls -l "$log" 2>&1`;		#file time-stamp & size
	if [ ."$n" != ."$t" ]; then
		# file has changed in size or time: show its contents
		cnt=$(( $cnt + 1 ));	#increase $cnt ONLY IF file changes
		t="$n";			#remember new state
		echo " ";		#double space
		echo "$cnt: $n";	#put out heading, with changing cnt
		if [ -f "$log" ]; then	#if file exists,
			cat "$log";	##put it out ($n has any no file error)
		    fi
		echo " "
		date "+%T: sleeping $cnt for change to file"
	    fi
	nice -3 sleep $sleep || exit 11;  #don't eat infinite cpu time
     done;
     echo "exiting log watch";	#not sure how we can get here, but just in case
     exit 4;			#unusual exit code just for the heck of it
  fi
# }


#
#   log a few more details of possible interest
#

echo "perl details:" >>"$log"
$perl -e 'print "   rev=$]\n   \@INC=", join(":", @INC ), "\n";' >> "$log"
spew <<EOF >>"$log" --

#interesting values
HTTP_USER_AGENT='$HTTP_USER_AGENT'
REMOTE_ADDR=	'$REMOTE_ADDR'
REQUEST_METHOD=	'$REQUEST_METHOD'
SCRIPT_NAME=	'$SCRIPT_NAME'
QUERY_STRING= 	'$QUERY_STRING'
local id=`id`
uname=`uname -a`

EOF

#
#   execute the actual program
#	(execute in subshell to better isolate actions from our self)
#

date >>"$log" "+%T: executing $exe"
lines=`wc -l "$log" | awk '/[0-9]/ {print $1}'`;
lines=$(( $lines + 2 ));		#where 1st line of output should be
cat >>"$log" <<EOF
---------- begin cgi-bin output ---------- $lines
EOF
( $exe >>"$log" 2>>"$log".stderr "$@" ) 
status=$?;
linesout=`wc -l "$log" | awk '/[0-9]/ {print $1}'`;
linesout=$(( $linesout + 1 - $lines ));	 #total lines from cgi-bin program
#
#   check if it worked ("success" is finding a "Content-Type" header)
#
if head -40 "$log" | grep -i '^Content-Type *:' >/dev/null; then
	#log file apparently captured valid headers from cgi-bin
	tailx $lines "$log";	#relay output to the web browser
	Content_Type="";	#any further carping of ours does not need
	closeresponse
	date >>"$log" "+%T: successful completion";	#content type found
    else
	closeresponse
	carp "EXECUTION APPARENTLY FAILED: no headers observed (500)"
    fi
#
#   relay any stderr to true stderr
#
if [ -s "$log".stderr ]; then 
	date >>"$log" "+%T: STDERR detected: copying to true stderr"
	cat 1>&2 "$log".stderr; 

	#### now echo stderr to main log file
	carpStderr=true;	#signal that stderr is within the regular log
	cat <<EOF >>"$log"
---------- begin cgi-bin stderr ----------
EOF
	cat "$log".stderr >>"$log"
	cat <<EOF >>"$log"
---------- end   cgi-bin stderr ----------"
lines: $( wc -l "$log".stderr | awk '/[0-9]/ {print $1}' )
EOF
    fi


date >>"$log" "+%T: exit-status=$status"

echo >>"$log" "end of trace output"

exit $status

#end: cgibinIntercept.sh
