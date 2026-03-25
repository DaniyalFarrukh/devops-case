# ---- Build Stage ----
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# REACT_APP_API_URL is injected at build time via CI/CD
ARG REACT_APP_API_URL=http://localhost:5050
ENV REACT_APP_API_URL=$REACT_APP_API_URL

RUN npm run build

# ---- Runtime Stage (nginx) ----
FROM nginx:1.25-alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built React app
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
