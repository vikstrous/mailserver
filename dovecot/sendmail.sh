#!/bin/sh
/usr/sbin/sendmail -H 'exec socat - UNIX-CONNECT:/postfix/unixsubmission' $@
