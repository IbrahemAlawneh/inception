# Developer Documentation

## 1. Prerequisites

The project must be run inside a Virtual Machine.

Required tools:

- Docker
- Docker Compose v2
- Make
- Git

Check the installation:

```bash
docker --version
docker compose version
make --version
git --version
```

## 2. Configuration

### Environment Variables

Create the environment file:

```text
srcs/.env
```

It contains the project's non-sensitive configuration:

```env
MYSQL_DATABASE=
MYSQL_USER=

DOMAIN_NAME=
HTTPS_PORT=

WP_ADMIN=
WP_ADMIN_EMAIL=

WP_USER=
WP_USER_EMAIL=
```

Passwords must not be stored in `.env`.

### Docker Secrets

Sensitive credentials are stored in:

```text
secrets/
├── db_root_password
├── db_user_password
├── wp_admin_password
└── wp_user_password
```

Secret files must not be committed to Git.

## 3. Domain Configuration

Configure the project domain in `/etc/hosts`:

```bash
echo "127.0.0.1 ialalawn.42.fr" | sudo tee -a /etc/hosts
```

If the project is accessed through a Virtual Machine from another machine, use the VM's IP address instead.

## 4. Build and Launch

From the project root, build and start the infrastructure with:

```bash
make
```

The Makefile uses Docker Compose to build the custom images and launch the services.

The Compose configuration is located at:

```text
srcs/docker-compose.yml
```

## 5. Container Management

Check the running containers:

```bash
make ps
```

Follow the service logs:

```bash
make logs
```

Start stopped containers:

```bash
make start
```

Stop the infrastructure:

```bash
make stop
```

The equivalent Docker Compose commands are:

```bash
docker compose ps
docker compose logs -f
docker compose start
docker compose stop
docker compose down
```

## 6. Volume Management

The project uses two Docker named volumes:

- WordPress data
- MariaDB data

List volumes:

```bash
docker volume ls
```

Inspect a volume:

```bash
docker volume inspect <volume_name>
```

The persistent data is stored on the host under:

```text
/home/ialalawn/data/
```

The data survives container recreation as long as the persistent storage is preserved.

To remove the Docker Compose volumes:

```bash
docker compose down -v
```

Use this command carefully because removing volumes can affect persistent data.

## 7. Full Reset

To remove the infrastructure and persistent project data:

```bash
make fclean
```

Then rebuild and launch the project:

```bash
make
```

This starts the infrastructure from a clean persistent state.
