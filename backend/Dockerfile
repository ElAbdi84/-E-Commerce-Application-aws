# backend/Dockerfile

# Étape 1 : Image de base Node.js
FROM node:18-alpine AS base

# Créer le dossier de travail
WORKDIR /app

# Copier les fichiers package
COPY package*.json ./

# Installer les dépendances
RUN npm install --only=production

# Copier le code source
COPY . .

# Créer le dossier uploads
RUN mkdir -p public/uploads/products && \
    chmod -R 755 public/uploads

# Exposer le port
EXPOSE 5000

# Variables d'environnement par défaut
ENV NODE_ENV=production
ENV PORT=5000

# Démarrer l'application
CMD ["node", "server.js"]