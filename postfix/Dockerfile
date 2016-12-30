FROM alpine:3.4

# the uid/gid for postfix match up with the uid/gid for amavis so that amavis
# can send mail back in through the unix domain socket created by postfix
RUN addgroup -g 3001 postfix
RUN adduser -D -s /sbin/nologin -u 2001 -G postfix postfix
RUN addgroup -g 3003 postdrop
RUN adduser -D -s /sbin/nologin -u 2003 -G postdrop vmail

# TODO: check if we need certs and openssl for postfix
RUN apk add -uU openssl ca-certificates postfix rsyslog && \
    rm -rf /var/cache/apk/*

ADD rsyslog.conf /etc/rsyslog.conf

RUN postconf -e smtpd_tls_auth_only=yes && \
    postconf -e smtpd_tls_cert_file=/cert/cert.pem && \
    postconf -e smtpd_tls_key_file=/cert/key.pem && \
    postconf -e smtpd_tls_mandatory_ciphers=high && \
    postconf -e smtpd_sasl_auth_enable=yes && \
    postconf -e smtpd_sasl_type=dovecot && \
    postconf -e smtp_use_tls=yes && \
    postconf -e smtpd_sasl_path=private/dovecot/auth && \
    postconf -e 'smtpd_sasl_local_domain=$mydomain' && \
    postconf -e 'smtpd_recipient_restrictions = '\
permit_sasl_authenticated,\
permit_mynetworks,\
reject_unauth_destination,\
reject_invalid_hostname,\
reject_non_fqdn_hostname,\
reject_non_fqdn_sender,\
reject_non_fqdn_recipient,\
reject_unknown_sender_domain,\
reject_unknown_recipient_domain,\
reject_unauth_pipelining,\
'reject_rbl_client zen.spamhaus.org,'\
permit && \
    postconf -e smtpd_sender_restrictions=reject_sender_login_mismatch && \
    postconf -e smtpd_sender_login_maps=hash:/etc/postfix/vmailbox && \
    postconf -e virtual_mailbox_maps=hash:/etc/postfix/vmailbox && \
    postconf -e virtual_alias_maps=hash:/etc/postfix/vmailbox && \
    postconf -e virtual_transport=lmtp:unix:private/dovecot/lmtp && \
    postconf -e mydestination= && \
    postconf -e milter_default_action=accept && \
    postconf -e mailbox_size_limit=0 && \
    postconf -e message_size_limit=0 && \
    postconf -e 'smtpd_tls_session_cache_database=btree:${data_directory}/smtpd_scache' && \
    postconf -e 'smtp_tls_session_cache_database=btree:${data_directory}/smtp_scache' && \
    postconf -e inet_protocols=all && \
    postconf -e mynetworks=127.0.0.0/8 && \
    postconf -M submission/inet='submission inet n - n - - smtpd' && \
    postconf -P submission/inet/smtpd_tls_wrappermode=yes && \
    postconf -M smtps/inet='smtps inet n - n - - smtpd' && \
    postconf -P smtps/inet/smtpd_tls_wrappermode=yes && \
    postconf -P smtps/inet/content_filter=lmtp:unix:/var/amavis/sock/amavisd.sock && \
    postconf -P smtp/inet/smtpd_tls_security_level=encrypt && \
    postconf -P smtp/inet/content_filter=lmtp:unix:/var/amavis/sock/amavisd.sock && \
    postconf -M unixsubmission/unix='unixsubmission unix n - - - - smtpd' && \
    postconf -P unixsubmission/unix/content_filter= && \
    postconf -P unixsubmission/unix/smtpd_sasl_auth_enable=no && \
    postconf -P unixsubmission/unix/smtpd_delay_reject=no && \
    postconf -P unixsubmission/unix/smtpd_client_restrictions=permit_mynetworks,reject && \
    postconf -P unixsubmission/unix/smtpd_helo_restrictions= && \
    postconf -P unixsubmission/unix/smtpd_sender_restrictions= && \
    postconf -P unixsubmission/unix/smtpd_recipient_restrictions=permit_mynetworks,reject && \
    postconf -P unixsubmission/unix/smtpd_data_restrictions=reject_unauth_pipelining && \
    postconf -P unixsubmission/unix/smtpd_end_of_data_restrictions= && \
    postconf -P unixsubmission/unix/smtpd_restriction_classes= && \
    postconf -P unixsubmission/unix/mynetworks=127.0.0.0/8 && \
    postconf -P unixsubmission/unix/smtpd_error_sleep_time=0 && \
    postconf -P unixsubmission/unix/smtpd_soft_error_limit=1001 && \
    postconf -P unixsubmission/unix/smtpd_hard_error_limit=1000 && \
    postconf -P unixsubmission/unix/smtpd_client_connection_count_limit=0 && \
    postconf -P unixsubmission/unix/smtpd_client_connection_rate_limit=0 && \
    postconf -P unixsubmission/unix/receive_override_options=no_header_body_checks,no_unknown_recipient_checks,no_milters && \
    postconf -P unixsubmission/unix/local_header_rewrite_clients= && \
    postconf -P unixsubmission/unix/smtpd_tls_security_level=none && \
    postconf -P unixsubmission/unix/local_recipient_maps= && \
    postconf -P unixsubmission/unix/relay_recipient_maps=

# TODO: get rid of the need to delete /var/run/rsyslogd.pid on start up

CMD echo "@$mail_for_fqdn $user" > /etc/postfix/vmailbox && \
    postmap hash:/etc/postfix/vmailbox && \
    postconf -e virtual_mailbox_domains=$mail_for_fqdn && \
    postconf -e myorigin=$mail_for_fqdn && \
    postconf -e myhostname=$mailserver_fqdn && \
    newaliases && \
    rm -f /var/run/rsyslogd.pid && \
    /usr/sbin/rsyslogd -n & \
    tail -F /var/log/maillog & \
    /usr/lib/postfix/master -d -v
