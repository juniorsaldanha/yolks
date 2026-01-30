FROM  --platform=$TARGETOS/$TARGETARCH ghcr.io/pterodactyl/yolks:java_25

LABEL author="Junior Saldanha" maintainer="umsaldanha@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/juniorsaldanha/yolks"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.description="Hytale dedicated server."

USER root

COPY --from=ghcr.io/pterodactyl/yolks:java_25 entrypoint.sh /java.sh
RUN chmod +x /java.sh

# Install required packages using apt (Debian package manager)
RUN apt-get update \
    && apt-get install -y \
    unzip \
    jq \
    coreutils \
    bash \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure
# /opt/hytale - System files (hidden from users)
# /home/container - User files only
RUN mkdir -p /opt/hytale/bin \
    && mkdir -p /opt/hytale/assets \
    && mkdir -p /home/container/Server \
    && chown -R container:container /home/container \
    && chmod 755 /home/container \
    && chmod 755 /opt/hytale

# Create a wrapper script for the hytale-downloader that uses unbuffered output
COPY ./entrypoint.sh /entrypoint.sh
COPY .pteroignore /pteroignore
RUN chmod +x /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

CMD [ "/bin/bash", "/entrypoint.sh" ]
