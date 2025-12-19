# PostgreSQL with pgvector and pgvectorscale

Image Docker PostgreSQL 17.2 basée sur [CloudNativePG](https://cloudnative-pg.io/) avec les extensions [pgvector](https://github.com/pgvector/pgvector) et [pgvectorscale](https://github.com/timescale/pgvectorscale) pré-installées.

## Extensions incluses

- **pgvector v0.8.0** : Support des vecteurs pour l'embedding et la recherche de similarité
- **pgvectorscale** : Optimisations et fonctionnalités avancées pour pgvector (DiskANN, streaming replication)

## Utilisation

### Pull de l'image

```bash
docker pull ghcr.io/jzacharie/pg-vectorscale:latest
```

> [!NOTE]
> Cette image est construite pour l'architecture **linux/amd64** uniquement, optimisée pour des builds rapides (~20-30 minutes).

### Démarrage rapide

```bash
docker run -d \
  --name postgres-vector \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  ghcr.io/jzacharie/pg-vectorscale:latest
```

### Activation des extensions

```sql
-- Créer l'extension pgvector
CREATE EXTENSION vector;

-- Créer l'extension pgvectorscale (nécessite pgvector)
CREATE EXTENSION vectorscale CASCADE;
```

### Exemple d'utilisation

```sql
-- Créer une table avec des vecteurs
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding vector(3)
);

-- Insérer des données
INSERT INTO items (embedding) VALUES 
  ('[1,2,3]'),
  ('[4,5,6]');

-- Recherche de similarité
SELECT * FROM items 
ORDER BY embedding <-> '[3,1,2]' 
LIMIT 5;
```

## Utilisation avec CloudNativePG

### Configuration du Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-vector-cluster
spec:
  instances: 3
  imageName: ghcr.io/jzacharie/pg-vectorscale:latest
  
  storage:
    size: 10Gi
  
  bootstrap:
    initdb:
      database: app
      owner: app
      postInitSQL:
        - CREATE EXTENSION vector;
        - CREATE EXTENSION vectorscale CASCADE;
```

## Build local

### Prérequis

- Docker
- Au moins 4GB de RAM disponible pour le build
- Connexion Internet (pour télécharger les dépendances)

### Commandes

```bash
# Build de l'image
docker build -t pg-vectorscale:local .

# Test de l'image
docker run --rm -e POSTGRES_PASSWORD=test pg-vectorscale:local postgres --version
```

### Build multi-plateforme

Si vous avez besoin du support arm64, modifiez `.github/workflows/docker-build.yaml` :

```yaml
platforms: linux/amd64,linux/arm64
```

> [!WARNING]
> Le build multi-plateforme prendra environ 2x plus de temps (~40-60 minutes au total).
```

## Versions

L'image est basée sur PostgreSQL 17.2. Pour utiliser une version différente, modifiez le tag de l'image de base dans le Dockerfile :

```dockerfile
FROM ghcr.io/cloudnative-pg/postgresql:17.7 AS builder
# ...
FROM ghcr.io/cloudnative-pg/postgresql:17.7
```

## Release

Pour créer une nouvelle release :

1. Créer un tag de version :
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. La GitHub Action construira automatiquement et publiera l'image sur GHCR avec les tags :
   - `ghcr.io/jzacharie/pg-vectorscale:1.0.0`
   - `ghcr.io/jzacharie/pg-vectorscale:1.0`
   - `ghcr.io/jzacharie/pg-vectorscale:1`
   - `ghcr.io/jzacharie/pg-vectorscale:latest`

## Documentation

- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [pgvectorscale Documentation](https://github.com/timescale/pgvectorscale)
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)

## Licence

Ce projet utilise des composants open-source. Consultez les licences respectives :
- PostgreSQL : PostgreSQL License
- pgvector : PostgreSQL License
- pgvectorscale : PostgreSQL License