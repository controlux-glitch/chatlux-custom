#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

pnpm store prune

if [ ! -d /app/node_modules ] || [ -z "$(ls -A /app/node_modules 2>/dev/null)" ]; then
  pnpm install
else
  echo "node_modules already present, skipping pnpm install."
fi

echo "Ready to run Vite development server."

exec "$@"
