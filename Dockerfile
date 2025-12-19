# --- Étape 1 : Construction ---
FROM ghcr.io/cloudnative-pg/postgresql:17.7 AS builder

USER root

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-17 \
    curl \
    git \
    cmake \
    libclang-dev \
    pkg-config \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Installation de Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install sccache for Rust compilation caching
RUN cargo install sccache --locked
ENV RUSTC_WRAPPER=sccache
ENV SCCACHE_DIR=/root/.cache/sccache

# Clone pgvectorscale first to detect pgrx version
RUN git clone https://github.com/timescale/pgvectorscale.git /tmp/pgvectorscale

# Install cargo-pgrx with the same version as pgrx dependency
RUN cd /tmp/pgvectorscale/pgvectorscale && \
    PGRX_VERSION=$(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version') && \
    cargo install --locked cargo-pgrx --version $PGRX_VERSION && \
    cargo pgrx init --pg17 /usr/bin/pg_config

# 1. Compilation de pgvector (pré-requis)
RUN git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git /tmp/pgvector \
    && cd /tmp/pgvector \
    && make clean && make && make install

# 2. Compilation de pgvectorscale
RUN cd /tmp/pgvectorscale/pgvectorscale \
    && cargo pgrx install --release \
    && echo "=== Verifying pgvectorscale installation ===" \
    && ls -la /usr/lib/postgresql/17/lib/ | grep -i vector || echo "No vector files in lib" \
    && ls -la /usr/share/postgresql/17/extension/ | grep -i vector || echo "No vector files in extension" \
    && find /usr -name "vectorscale.so" 2>/dev/null || echo "vectorscale.so not found anywhere"

# --- Étape 2 : Image Finale ---
# Remplacez 17.2 par 17.7 dès qu'elle est disponible sur ghcr.io
FROM ghcr.io/cloudnative-pg/postgresql:17.7

USER root

# Récupération de pgvector
COPY --from=builder /usr/lib/postgresql/17/lib/vector.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/vector* /usr/share/postgresql/17/extension/

# Récupération de pgvectorscale
COPY --from=builder /usr/lib/postgresql/17/lib/vectorscale*.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/vectorscale* /usr/share/postgresql/17/extension/

# CNPG tourne avec l'utilisateur 26
USER 26
