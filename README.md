# vikstrous/mailserver

A set of docker images and instructions that can be used to set up a simple mail server for a single user.

Features:

* TLS + instructions for how to set up with let's encrypt
* SMTP and IMAP
* Simple config - just specify your domains, username, password. The rest is
  just setting up DNS
* Catchall domain
* Spam detection
* Sieve filter support
* DKIM signing
* DKIM, SPF, DMARC set up instructions
* Instructions for how to test the result

Expected set up time: 1 hour

## Usage

### Initialize your repo and set up some configs

1. Add this repo as a submodule
    ```
    git submoudle add https://github.com/vikstrous/mailserver
    git submodule update --init
    ```
2. Link the docker compose file `ln -s ./mailserver/docker-compose.yml`
3. Create the directories used for secrets: `mkdir -p ./cert ./dkim`
4. Create a file called `./env` filling out the following data:

    ```
    mail_for_fqdn=
    mailserver_fqdn=
    user=
    ```

    * The mail server should be at the `mail.` subdomain to make autodiscovery work easily in mail clients. In other words, if `mail_for_fqdn` is example.com `mailserver_fqdn` is mail.example.com
    * Note that this user can be anything and doesn't need to exist on the host. It will be the username used to log into your mail server.

4. Generate a password hash for auth

    * Use `python3 -c 'import crypt; print(crypt.crypt("password", crypt.mksalt(crypt.METHOD_SHA512)))'`, replacing `password` with your password
    * Put the result in `./env` as `pass=$6$...`

5. Generate a DKIM key

    * `opendkim-genkey --hash-algorithms sha256 --bits 2048 --domain $MAILSERVER_FQDN --directory ./dkim --selector default --restrict`
    * The result will be an RSA key in `./dkim/default.private`
    * Don't use keys larger than 4096 for now because verifiers may not support them, which would defeat the whole point of DKIM
    * Note the contents of `dkim/default.txt` - you will use this for your DKIM DNS records

### Create your server and install the basics

1. Get a server - aws, vultr, digital ocean, linode, whatever. You need 512MB of RAM.
2. Get a domain and add an A record for your mail subdomain.
3. Install docker `curl https://get.docker.com | sudo sh` (known to work with docker 1.12)
5. For convenience `sudo usermod -aG docker your-user` if not using the root user
6. Get docker compose:

    ```
    curl -L "https://github.com/docker/compose/releases/download/1.9.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ```

### Set up DNS

* Create an A record for your subdomain
* Create an MX record with value $MAILSERVER_FQDN and priority 1
* DKIM
    * Set up a TXT record with the key `default._domainkey`
    * Use the contents of `./dkim/default.txt` generated earlier for the value of the TXT record
    * This should already be done for you by opendkim-genkey, but if not, split up the value using multiple quoted strings separated by spaces such that none of the strings is longer than 256 characters
* SPF
    * Create a TXT record with the key `@` and value `"v=spf1 mx -all"`
* DMARC
    * Create a TXT record with the key `_dmarc` and value `v=DMARC1; p=reject; rua=mailto:dmarc@$MAIL_FOR_FQDN; ruf=mailto:dmarc-violation@$MAIL_FOR_FQDN; sp=reject; fo=1; aspf=s; adkim=s; pct=100`
    * Read up on dmarc and customize the record to your liking. The above example is the strictest possible mode.

### TLS cert

Wait for the DNS A record to propagate. Try resolving your hostname from your
server a few times until it works, then choose one of the following options to
get a TLS cert:

* Using Let's Encrypt

    * On your server:
    * run this on your server `docker run -it --rm -p 443:443 -p 80:80 --name certbot -v $(pwd)/out:/out --entrypoint sh quay.io/letsencrypt/letsencrypt:latest -c "certbot certonly --non-interactive --standalone --agree-tos --email a@example.com -d $MAILSERVER_FQDN && tar -c /etc/letsencrypt/archive/$MAILSERVER_FQDN > /out/certs.tar"`
    * `cd out`
    * `tar -xvf certs.tar`
    * Your certs are in `etc/letsencrypt/archive/$MAILSERVER_FQDN/fullchain1.pem` and `etc/letsencrypt/archive/$MAILSERVER_FQDN/privkey1.pem`. Copy them to your project as `./cert/cert.pem` and `./cert/key.pem` respectively

* Or with a real CA

    * In your project directory
    * Generate the key and csr

        ```
        openssl genrsa -out ./cert/key.pem 4096
        openssl req -new -key ./cert/key.pem -out ./cert/csr.pem
        ```
    * Get the cert issued and put it in `./cert/cert.pem`

* Or with a self signed cert

    * In your project directory
    * `openssl req -x509 -newkey rsa:4096 -keyout ./cert/key.pem -out ./cert/cert.pem -days 365`

### Run

Now that everything is ready, commit all your secrets to git, push them, then
clone the repo onto your server and run `docker-compose up -d`. Sorry about the
lame secret management. Encrypting the secrets is left as an exercise to the
reader.

### Test

* https://mail-tester.com/
* https://mxtoolbox.com/diagnostic.aspx
* https://checktls.com/perl/TestSender.pl
* https://checktls.com/perl/TestReceiver.pl

### Extra configs

* To configure sieve copy `sieve.example` from the root of this repo into `./sieve/sieve` in your repo then modify it to fit your needs

### Upgrade


In your repo:

```
cd mailserver
git pull
cd ..
git add mailserver
git commit -m 'update mailserver'
git push
```

On the server:

```
docker-compose up --build -d
```

### Changing domains

There is no easy way to do this without down time, so here's one way you can do
it while having minimal down time

1. Note your current DNS TTL value -> X seconds
1. Set your DNS's TTL to a low value like 10 seconds
2. Wait X seconds for any downstream DNS servers to update their cache
3. Add a DNS record for your new domain to point to your mail server (in
   addition to the old one)
4. Wait for DNS to start working
5. Get new TLS certs using the let's encrypt method I described above
6. Set up any additional DNS records for DKIM, etc. by following the
   original instructions for setting up a mail server.
7. Replace and commit the new certs to your repo
8. Check out the new version on your server
9. Run `docker-compose up --force-recreate -d` to update the server
10. After making sure everything is working, increase your DNS's TTL again and remove any DNS entries you are not using any more

The down time should happen only between step 8 and the end of step 9.
