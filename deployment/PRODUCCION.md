# Chatlux en app-server2

Instalación nueva para `https://chatwoot.controlux.com.mx` en el proyecto
`nafta-lux`, zona `us-south1-a`. Rails escucha en `10.206.0.9:3000`, la IP privada
de `app-server2`. PostgreSQL y Redis no publican puertos del host.

## Configuración

- Compose: `/opt/chatlux/docker-compose.gcp.yaml`.
- Variables y secretos: `/opt/chatlux/.env` (permisos `600`, fuera de Git).
- Código de cada versión: `/opt/chatlux-releases/<commit>`.
- Imagen propia: `chatlux:<commit>`, seleccionada mediante `CHATLUX_IMAGE`.
- Volúmenes persistentes: `chatlux_postgres_data`, `chatlux_redis_data` y
  `chatlux_storage_data`.
- VM: 4 GB de RAM y 4 GB de swap persistente en `/swapfile-chatlux`.

`deployment/Dockerfile.gcp` reutiliza la imagen oficial `v4.18.0`, fijada por
digest, y compila el código y frontend propios. Comprueba que `Gemfile.lock`
coincida exactamente antes de reutilizar las gemas. Si cambian las dependencias
Ruby, actualizar la base o construirlas con `docker/Dockerfile`.

Construir desde el directorio del release:

```sh
sudo docker build -f deployment/Dockerfile.gcp -t chatlux:<commit> .
```

En el servidor, los comandos de administración usan:

```sh
sudo docker compose --env-file /opt/chatlux/.env -f /opt/chatlux/docker-compose.gcp.yaml ps
sudo docker compose --env-file /opt/chatlux/.env -f /opt/chatlux/docker-compose.gcp.yaml logs --tail=100 rails sidekiq
```

El correo usa Brevo (`smtp-relay.brevo.com`, puerto `465`) con TLS implícito:
`SMTP_SSL=true`, `SMTP_TLS=false`, `SMTP_ENABLE_STARTTLS_AUTO=false` y
`SMTP_AUTHENTICATION=login`. El remitente es `chatwoot@controlux.com.mx`.
Las credenciales están únicamente en `.env`. Recrear Rails y Sidekiq con
`docker compose up -d rails sidekiq` tras modificar las variables de correo.

El nodo `AI` de los flujos aún no tiene implementación de proveedor y devuelve
un error explícito si se ejecuta.

## Cambio manual en Nginx del proxy

Solo modificar el bloque correspondiente a `chatwoot.controlux.com.mx`.
Conservar las rutas actuales del certificado. Añadir `client_max_body_size 20m;`
al bloque `server` y reemplazar su `location /` por:

```nginx
location / {
    proxy_pass http://10.206.0.9:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header api_access_token $http_api_access_token;
    proxy_read_timeout 3600s;
    proxy_buffering off;
}
```

El operador del proxy debe validar y recargar:

```sh
sudo nginx -t && sudo systemctl reload nginx
```

No hace falta cambiar DNS: ya apunta al proxy. Tras conectar el proxy, abrir
`https://chatwoot.controlux.com.mx/installation/onboarding` para crear el primer
superadministrador. El registro público queda desactivado.

## Respaldos

`backup-chatlux.sh` guarda PostgreSQL, adjuntos y configuración en
`/opt/chatlux/backups/`, accesible solamente por root. El respaldo contiene
secretos. No subirlo a Git ni compartirlo.

`chatlux-backup.timer` programa el respaldo a las 02:15 de Ciudad de México.
Comprobarlo con `sudo systemctl list-timers chatlux-backup.timer` y ejecutar un
respaldo manual con `sudo systemctl start chatlux-backup.service`.

Los respaldos locales no protegen frente a la pérdida del disco o de la VM.
Configurar almacenamiento externo y retención antes de depender de la instancia
para datos críticos. Vigilar el espacio disponible mientras no haya retención.

## Actualizaciones

Respaldar primero. Construir una imagen con un tag correspondiente al commit,
actualizar `CHATLUX_IMAGE` en `.env`, ejecutar `db:chatwoot_prepare` con la imagen
nueva y recrear Rails y Sidekiq. Conservar la imagen anterior para revertir el
código; una reversión con cambios de esquema puede requerir restaurar el
respaldo. Nunca ejecutar `docker compose down -v` en producción.
