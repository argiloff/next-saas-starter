# 1. Basis-Image für Node.js
FROM node:18-alpine AS base

# Installiere erforderliche Bibliotheken
RUN apk add --no-cache libc6-compat

# Arbeitsverzeichnis setzen
WORKDIR /app

# 2. Abhängigkeiten installieren
FROM base AS deps

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# 3. Anwendung bauen
FROM base AS builder

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Optional: Deaktiviere Telemetrie
ENV NEXT_TELEMETRY_DISABLED 1

RUN \
  if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# 4. Produktions-Image
FROM base AS runner

WORKDIR /app

ENV NODE_ENV production

# Benutzer hinzufügen (sicherheitsrelevant)
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Statische und standalone Dateien kopieren
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

# Port für die Anwendung
EXPOSE 3000
ENV PORT 3000

# Anwendung starten
CMD ["node", "server.js"]
