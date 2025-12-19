# --- Étape 1 : Construction ---
FROM ghcr.io/cloudnative-pg/postgresql:17.2 AS builder

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
    && rm -rf /var/lib/apt/lists/*

# Installation de Rust et cargo-pgrx
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install --locked cargo-pgrx --version 0.12.6
RUN cargo pgrx init --pg17 /usr/bin/pg_config

# 1. Compilation de pgvector (pré-requis)
RUN git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git /tmp/pgvector \
    && cd /tmp/pgvector \
    && make clean && make && make install

# 2. Compilation de pgvectorscale
RUN git clone https://github.com/timescale/pgvectorscale.git /tmp/pgvectorscale \
    && cd /tmp/pgvectorscale/pgvectorscale \
    && cargo pgrx install --release

# --- Étape 2 : Image Finale ---
# Remplacez 17.2 par 17.7 dès qu'elle est disponible sur ghcr.io
FROM ghcr.io/cloudnative-pg/postgresql:17.2

USER root

# Récupération de pgvector
COPY --from=builder /usr/lib/postgresql/17/lib/vector.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/vector* /usr/share/postgresql/17/extension/

# Récupération de pgvectorscale
COPY --from=builder /usr/lib/postgresql/17/lib/vectorscale.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/vectorscale* /usr/share/postgresql/17/extension/

# CNPG tourne avec l'utilisateur 26
USER 26
