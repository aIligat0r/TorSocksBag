FROM debian:stable-slim


WORKDIR /app

RUN apt update && \
    apt install -y --no-install-recommends && \
    apt clean -y && \
    apt autoremove -y && \
    apt autoclean -y && \
    apt install -y \
    # Fix (by update openssl/libssl3):
        # - CVE-2026-28390
        # - CVE-2026-28388
        # - CVE-2026-28389
    openssl \
    libssl3 \
    ###
    tor \
    obfs4proxy \
    curl \
    net-tools \
    bash \
    socat \
    jq && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/
COPY templates/torrc.template /etc/tor/
COPY .env /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh


# Change if more
EXPOSE 9050-9150

ENTRYPOINT ["entrypoint.sh"]
