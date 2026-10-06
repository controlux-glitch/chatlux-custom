# Ejecutar Chatwoot en desarrollo

Esta guía inicia la aplicación mediante Docker Compose. Es la opción recomendada
en Windows porque mantiene Ruby, Node, PostgreSQL y Redis dentro de contenedores.

## Requisitos

- Docker Desktop iniciado y configurado para usar contenedores Linux.
- Git.
- Un archivo `.env` en la raíz del repositorio. Si aún no existe, créalo desde el
  ejemplo y define valores no vacíos para `SECRET_KEY_BASE`, `POSTGRES_PASSWORD`
  y `REDIS_PASSWORD`.

```powershell
Copy-Item .env.example .env
```

Para generar un secreto local para `SECRET_KEY_BASE`:

```powershell
-join (1..64 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
```

Usa `FRONTEND_URL=http://localhost:3000` y, para el correo local, configura
`SMTP_ADDRESS=mailhog`.

## Primer arranque: paso a paso

Ejecuta cada comando y espera a que termine correctamente antes de continuar.
No uses `docker compose up -d --build` en el primer arranque: Docker Compose
puede intentar compilar las imágenes dependientes en paralelo antes de crear la
imagen base local.

1. Inicia Docker Desktop y espera a que indique que está en ejecución.

2. Sitúate en la raíz del proyecto:

   ```powershell
   Set-Location C:\docker\chatwoot-test\chatwoot
   ```

3. Crea la imagen base local. Este paso puede tardar varios minutos:

   ```powershell
   docker compose build base
   ```

4. Confirma que la imagen base existe. Debe devolver un identificador, no un
   error:

   ```powershell
   docker image inspect chatwoot:development --format '{{.Id}}'
   ```

5. Compila la imagen de Rails, que también utiliza Sidekiq:

   ```powershell
   docker compose build rails
   ```

6. Compila la imagen de Vite después de la imagen base:

   ```powershell
   docker compose build vite
   ```

7. Inicia los servicios sin volver a compilar ni intentar descargar imágenes:

   ```powershell
   docker compose up -d --no-build
   ```

8. Espera a que Rails esté en estado `running` y prepara la base de datos:

   ```powershell
   docker compose ps
   docker compose exec rails bundle exec rails db:chatwoot_prepare
   ```

9. Comprueba el estado final:

   ```powershell
   docker compose ps
   ```

El mensaje `pull access denied for chatwoot-rails` o
`pull access denied for chatwoot-vite` significa que se saltaron los pasos de
compilación ordenada. No hace falta ejecutar `docker login`; vuelve al paso 3.

Servicios esperados: `rails`, `vite`, `sidekiq`, `postgres`, `redis` y `mailhog`.

## Abrir la aplicación

- Chatwoot: http://localhost:3000
- MailHog (correos locales): http://localhost:8025
- Vite: http://localhost:3036

### Usuario maestro local

En desarrollo, `db:chatwoot_prepare` carga las semillas locales y crea un
superadministrador confirmado. No necesitas registrarte ni confirmar un correo:

| Acceso | URL | Credenciales |
| --- | --- | --- |
| Panel de Chatwoot | http://localhost:3000/app/login | `john@acme.inc` / `Password1!` |
| Panel global de superadministración | http://localhost:3000/super_admin/sign_in | `john@acme.inc` / `Password1!` |

La página de instalación inicial se usa en producción. En desarrollo se
reemplaza por estos datos de prueba y por las cuentas de ejemplo `Acme Inc` y
`Acme Org`.

El registro en `/app/auth/signup` crea un administrador para una cuenta nueva,
no un superadministrador global, y solicita confirmación por correo. Evítalo
para el primer acceso local.

## Trabajo diario

Después del primer arranque basta con:

```powershell
docker compose up -d --no-build
```

Ver los registros de todos los servicios:

```powershell
docker compose logs -f
```

O solo los de Rails:

```powershell
docker compose logs -f rails
```

Después de modificar dependencias Ruby o JavaScript, vuelve a construir:

```powershell
docker compose build base
docker compose build rails
docker compose build vite
docker compose up -d --no-build
```

## Detener el entorno

Detiene los contenedores y conserva la base de datos:

```powershell
docker compose down
```

Para eliminar también las bases y cachés locales (acción irreversible):

```powershell
docker compose down -v
```
