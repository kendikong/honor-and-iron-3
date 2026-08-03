# Cloud Agent base for Honor & Iron 3 — Godot 4.7 baked into the image.
# Do not COPY the project; Cursor checks out the workspace separately.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		unzip \
		libfontconfig1 \
		libglu1-mesa \
		libxcursor1 \
		libxi6 \
		libxinerama1 \
		libxrandr2 \
		libx11-6 \
	&& curl -fsSL --retry 3 -o /tmp/godot.zip \
		https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip \
	&& unzip -o /tmp/godot.zip -d /tmp \
	&& mv /tmp/Godot_v4.7-stable_linux.x86_64 /usr/local/bin/godot \
	&& chmod +x /usr/local/bin/godot \
	&& rm -f /tmp/godot.zip \
	&& godot --version \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*
