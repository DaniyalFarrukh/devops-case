# ---- Build Stage ----
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

# ---- Runtime Stage ----
FROM node:18-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Remove example env file so secrets are injected at runtime
RUN rm -f .env-example

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 5050

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:5050/healthcheck || exit 1

CMD ["node", "server.mjs"]
