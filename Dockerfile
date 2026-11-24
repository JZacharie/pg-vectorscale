# --- Étape 1 : Construction ---
FROM ghcr.io/cloudnative-pg/postgresql:17.9-system-trixie AS builder

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

# Clone pgvectorscale 0.9.1 first to detect pgrx version
RUN git clone --branch 0.9.1 --depth 1 https://github.com/timescale/pgvectorscale.git /tmp/pgvectorscale

# Install cargo-pgrx with the same version as pgrx dependency
RUN cd /tmp/pgvectorscale/pgvectorscale && \
    PGRX_VERSION=$(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version') && \
    cargo install --locked cargo-pgrx --version $PGRX_VERSION && \
    cargo pgrx init --pg17 /usr/bin/pg_config

# Compilation de pgvectorscale pour PostgreSQL 17 (Trixie)
RUN cd /tmp/pgvectorscale/pgvectorscale \
    && cargo pgrx install --release --no-default-features --features "pg17,build_parallel" \
    && echo "=== Verifying pgvectorscale installation ===" \
    && ls -la /usr/lib/postgresql/17/lib/ | grep -i vector \
    && ls -la /usr/share/postgresql/17/extension/ | grep -i vector

# --- Étape 2 : Image Finale ---
FROM ghcr.io/cloudnative-pg/postgresql:17.9-system-trixie

USER root

# Récupération de pgvectorscale (pgvector est déjà inclus dans 17.9-system-trixie)
COPY --from=builder /usr/lib/postgresql/17/lib/vectorscale*.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/vectorscale* /usr/share/postgresql/17/extension/

# CNPG tourne avec l'utilisateur 26
USER 26
