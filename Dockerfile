FROM node:25.8.0-alpine AS build

WORKDIR /app

ARG BMS_ALLOWED_ORIGINS="https://hosxp.net https://10929-f446.tunnel.hosxp.net"
ENV THIP_BMS_ALLOWED_ORIGINS="${BMS_ALLOWED_ORIGINS}"
ARG VITE_BASE_PATH="/"
ENV VITE_BASE_PATH="${VITE_BASE_PATH}"
ARG VITE_BMS_APP_IDENTIFIER="THIP.KPI.BMS"
ENV VITE_BMS_APP_IDENTIFIER="${VITE_BMS_APP_IDENTIFIER}"

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN npm install --global pnpm@11.19.0 \
    && pnpm install --frozen-lockfile

COPY . .
RUN pnpm run build
RUN node scripts/render-nginx.mjs nginx.conf.template nginx.conf

FROM nginx:1.29.1-alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=build /app/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/nginx-main.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/cache/nginx /var/run \
    && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run

USER nginx
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
