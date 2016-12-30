FROM alpine:3.4

RUN addgroup -g 3001 dovecot
RUN addgroup -g 3003 postdrop
RUN adduser -D -s /sbin/nologin -u 2001 -G dovecot dovecot

# TODO: check if we need certs and openssl for dovecot
RUN apk add -uU openssl ca-certificates dovecot dovecot-pigeonhole-plugin socat && \
    rm -rf /var/cache/apk/*

ADD dovecot.conf /etc/dovecot/dovecot.conf
ADD conf.d/ /etc/dovecot/conf.d/
ADD sendmail.sh /bin/sendmail.sh

# the adduesr is relevant only the first time the container starts
# TODO: consider moving all non-standard configs to the dockerfile instead of
# keeping them in the individual files
# I don't know exactly why I need postdrop instead of dovecot for this user, but
# it works
CMD adduser -D -s /sbin/nologin "$user" -u 1000 -G postdrop; \
    sed -i "s/postmaster_address =.*/postmaster_address = $user@$mail_for_fqdn/" /etc/dovecot/conf.d/15-lda.conf && \
    sed -i "s|$user:!:|$user:$pass:|" /etc/shadow >> /etc/shadow && \
    chmod +r /etc/shadow && \
    dovecot -F
