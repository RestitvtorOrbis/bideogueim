# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG GODOT_VERSION=4.7.1
ARG GODOT_RELEASE=stable
ARG GODOT_ENGINE_SHA256=c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba
ARG GODOT_TEMPLATES_SHA256=86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION=$GODOT_VERSION
ENV GODOT_BIN=/opt/godot/godot
ENV GODOT_USER_HOME=/home/godot

RUN test "$GODOT_VERSION" = "4.7.1" \
    && test "$GODOT_RELEASE" = "stable"

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl unzip libfontconfig1 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin godot \
    && mkdir -p /opt/godot /home/godot/.local/share/godot/export_templates/$GODOT_VERSION.$GODOT_RELEASE \
    && chown -R godot:godot /opt/godot /home/godot

RUN curl --fail --location --retry 3 --output /tmp/godot.zip \
        "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip" \
    && echo "$GODOT_ENGINE_SHA256  /tmp/godot.zip" | sha256sum --check --status \
    && unzip -q /tmp/godot.zip -d /opt/godot \
    && mv /opt/godot/Godot_v4.7.1-stable_linux.x86_64 /opt/godot/godot \
    && rm /tmp/godot.zip \
    && chmod +x /opt/godot/godot

RUN --mount=type=cache,id=godot-4.7.1-templates,target=/var/cache/godot-downloads,sharing=locked \
    set -eu; \
    archive=/var/cache/godot-downloads/Godot_v4.7.1-stable_export_templates.tpz; \
    url=https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz; \
    if ! echo "$GODOT_TEMPLATES_SHA256  $archive" | sha256sum --check --status 2>/dev/null; then \
        attempt=1; \
        while ! curl --fail --location --continue-at - --connect-timeout 30 --output "$archive" "$url"; do \
            if [ "$attempt" -ge 10 ]; then \
                echo "Template download failed after $attempt attempts" >&2; \
                exit 1; \
            fi; \
            attempt=$((attempt + 1)); \
            sleep 5; \
        done; \
    fi; \
    if ! echo "$GODOT_TEMPLATES_SHA256  $archive" | sha256sum --check --status; then \
        rm -f "$archive"; \
        echo "Template checksum mismatch; cached archive removed" >&2; \
        exit 1; \
    fi; \
    mkdir -p /tmp/templates; \
    unzip -q "$archive" -d /tmp/templates; \
    cp -R /tmp/templates/templates/. /home/godot/.local/share/godot/export_templates/$GODOT_VERSION.$GODOT_RELEASE/; \
    chown -R godot:godot /home/godot; \
    rm -rf /tmp/templates

COPY tools/docker-entrypoint.sh /usr/local/bin/urban-drive-entrypoint
RUN chmod +x /usr/local/bin/urban-drive-entrypoint

WORKDIR /workspace
USER godot
ENTRYPOINT ["/usr/local/bin/urban-drive-entrypoint"]
