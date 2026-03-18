# ============================================================================
# DOCKERFILE - Worker SQS
# ============================================================================

FROM node:18-alpine

# Informations
LABEL maintainer="Oumayma El Abdi"
LABEL description="Worker SQS pour traitement asynchrone"

# Répertoire de travail
WORKDIR /app

# Copier package.json
COPY package*.json ./

# Installer dépendances
RUN npm install

# Copier le code
COPY . .

# Variables d'environnement par défaut
ENV NODE_ENV=production
ENV AWS_REGION=us-east-1

# Santé du container
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "console.log('Worker running')" || exit 1

# Démarrer le worker
CMD ["node", "index.js"]