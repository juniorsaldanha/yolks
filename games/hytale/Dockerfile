FROM  --platform=$TARGETOS/$TARGETARCH ghcr.io/pterodactyl/yolks:java_25

LABEL author="Junior Saldanha" maintainer="umsaldanha@gmail.com"

LABEL org.opencontainers.image.source="https://github.com/juniorsaldanha/yolks"
LABEL org.opencontainers.image.licenses=MIT

USER root

COPY --from=ghcr.io/pterodactyl/yolks:java_25 entrypoint.sh /java.sh
RUN chmod +x /java.sh

RUN apt-get update -y \
    && apt-get install -y unzip jq coreutils \
    && rm -rf /var/lib/apt/lists/*

# Fix permissions: Ensure the container user can write to /home/container
# This is critical for the hytale-downloader to save credentials
RUN mkdir -p /home/container \
    && chown -R container:container /home/container \
    && chmod 755 /home/container

# Create a wrapper script for the hytale-downloader that uses unbuffered output
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

CMD [ "/bin/bash", "/entrypoint.sh" ]
