# User Documentation

## 1. Services

The infrastructure provides three services:

- **NGINX** — The only public entry point. It provides secure HTTPS access using TLS.
- **WordPress + PHP-FPM** — Hosts and runs the WordPress website.
- **MariaDB** — Stores the WordPress database.

The services communicate through a private Docker network.

---

## 2. Start the Infrastructure

From the project root, run:

```bash
make
```

Check the services:

```bash
make ps
```

---

## 3. Stop the Infrastructure

To stop the running services:

```bash
make stop
```

To start them again:

```bash
make start
```

---

## 4. Access the Website

Open the following address in a web browser:

```text
https://ialalawn.42.fr
```

---

## 5. Access the Administration Panel

Open:

```text
https://ialalawn.42.fr/wp-login.php
```

Use the WordPress administrator credentials configured for the project.

---

## 6. Credentials

Sensitive credentials are stored locally in the `secrets/` directory:

```text
secrets/
├── db_root_password
├── db_user_password
├── wp_admin_password
└── wp_user_password
```

These files contain passwords and must not be committed to Git.

Non-sensitive configuration is stored in:

```text
srcs/.env
```

The WordPress administrator username and email are configured through the corresponding variables in `.env`.

---

## 7. Check Service Status

Check whether the containers are running:

```bash
make ps
```

To view the service logs:

```bash
make logs
```

You can also check the individual services with Docker Compose:

```bash
docker compose ps
```

View logs with:

```bash
docker compose logs -f
```

The expected services are:

```text
nginx
wordpress
mariadb
```

All three containers should be running for the complete infrastructure to function correctly.
