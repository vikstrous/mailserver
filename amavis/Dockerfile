FROM alpine:3.4

RUN addgroup -g 3001 amavis
RUN adduser -D -s /sbin/nologin -u 2001 -G amavis amavis
RUN addgroup -g 3002 clamav
RUN adduser -D -s /sbin/nologin -u 2002 -G clamav clamav

RUN apk add -uU spamassassin perl-mail-spamassassin amavisd-new curl clamav && \
    rm -rf /var/cache/apk/*

# We disable clamav with the lines between admin_maps_by_ccat and FOUND because
# it's too slow and uses too much RAM
RUN mkdir -p /var/amavis/sock && \
    chown amavis:amavis /var/amavis/sock && \
    sed -i "s/protocol => 'AM.PDP',/originating => 1,\\n  protocol => 'LMTP',/" /etc/amavisd.conf && \
    echo "\$notify_method  = 'smtp:/var/spool/postfix/public/unixsubmission';" >> /etc/amavisd.conf && \
    echo "\$forward_method  = 'smtp:/var/spool/postfix/public/unixsubmission';" >> /etc/amavisd.conf && \
    sed -i "s/sa_tag_level_deflt  = 2.0/sa_tag_level_deflt  = -999/" /etc/amavisd.conf && \
    echo '$admin_maps_by_ccat{+CC_UNCHECKED} = undef;' >> /etc/amavisd.conf && \
    echo '$undecipherable_subject_tag = undef;' >> /etc/amavisd.conf && \
    sed -i '/ClamAV-clamscan/,/Infected Archive/d' /etc/amavisd.conf && \
    mkdir -p /var/lib/clamav/ && \
    chown clamav:clamav /var/lib/clamav/ && \
    mkdir -p /etc/mail/spamassassin/sa-update-keys && \
    chmod 700 /etc/mail/spamassassin/sa-update-keys

CMD sed -i "s/# \$myhostname = 'host.example.com';/\$myhostname = '$mailserver_fqdn';/" /etc/amavisd.conf && \
    sed -i "s/example.com/$mail_for_fqdn/" /etc/amavisd.conf && \
    sed -i "s/\$sa_spam_subject_tag = '\\*\\*\\*Spam\\*\\*\\* ';/\$sa_spam_subject_tag = '';/" /etc/amavisd.conf && \
    (grep 'dkim_key(' /etc/amavisd.conf || echo 'dkim_key("'$mail_for_fqdn'", "default", "/dkim/default.private");' >> /etc/amavisd.conf) && \
    sa-update --gpghomedir /var/lib/spamassassin/sa-update-keys -D; \
    chown clamav:clamav /var/lib/clamav/ && \
    freshclam --debug && \
    rm -f /var/amavis/amavisd.pid && \
    amavisd -p /var/amavis/sock/amavisd.sock -m 1 debug-sa
