*This activity has been created as part of the 42 curriculum by ialalawn

# Inception

A containerized WordPress infrastructure built from scratch with **Docker**, **Docker Compose**, **NGINX**, **WordPress + PHP-FPM**, and **MariaDB**.

The project is designed around service isolation, secure configuration, persistent storage, internal networking, TLS termination, and reproducible infrastructure management.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Requirements & Design Constraints](#requirements--design-constraints)
- [Core Design Decisions](#core-design-decisions)
  - [Virtual Machines vs Docker](#1-virtual-machines-vs-docker)
  - [Secrets vs Environment Variables](#2-secrets-vs-environment-variables)
  - [Docker Network vs Host Network](#3-docker-network-vs-host-network)
  - [Docker Volumes vs Bind Mounts](#4-docker-volumes-vs-bind-mounts)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Docker Secrets](#docker-secrets)
  - [Domain Configuration](#domain-configuration)
- [Build & Run](#build--run)
- [Makefile Commands](#makefile-commands)
- [Accessing the Application](#accessing-the-application)
- [Service Responsibilities](#service-responsibilities)
- [Data Persistence](#data-persistence)
- [Networking & Security](#networking--security)
- [Troubleshooting](#troubleshooting)
- [Useful Docker Commands](#useful-docker-commands)
- [Resources](#resources)
- [AI Usage](#ai-usage)
- [Author](#author)

---

## Overview

The **Inception** activity is a System Administration project focused on building a small production-style infrastructure using Docker.

The infrastructure contains three independent services:

| Service | Responsibility | Publicly Exposed |
|---|---|---|
| **NGINX** | TLS termination and reverse proxy | **443 only** |
| **WordPress + PHP-FPM** | Web application and PHP execution | No |
| **MariaDB** | WordPress relational database | No |

Each service runs in its own dedicated container and communicates with the others through a user-defined Docker network.

The infrastructure is built from custom Dockerfiles rather than relying on pre-built application images.

---

## Architecture

```text
                         Internet / Host
                              │
                              │ HTTPS :443
                              ▼
                    ┌───────────────────┐
                    │   NGINX Container  │
                    │   TLS 1.2 / 1.3   │
                    └─────────┬─────────┘
                              │
                         FastCGI :9000
                              │
                              ▼
                    ┌───────────────────┐
                    │ WordPress + PHP-FPM│
                    │     Container     │
                    └─────────┬─────────┘
                              │
                           MySQL :3306
                              │
                              ▼
                    ┌───────────────────┐
                    │ MariaDB Container │
                    └───────────────────┘

                         Docker Network
                              │
              ┌───────────────┴───────────────┐
              │                               │
       WordPress Volume                MariaDB Volume
              │                               │
              ▼                               ▼
      /home/ialalawn/data/           /home/ialalawn/data/
          wordpress/                     mariadb/
```

### Request Flow

1. A client connects to `https://ialalawn.42.fr`.
2. NGINX accepts the connection on port **443**.
3. TLS is terminated by NGINX using TLS 1.2/1.3.
4. NGINX forwards PHP requests to WordPress through FastCGI.
5. WordPress communicates with MariaDB through the private Docker network.
6. MariaDB stores persistent database data in its dedicated volume.

NGINX is the **only public entry point**.

---

## Project Structure

The repository follows the structure expected by the activity:

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── db_root_password
│   ├── db_user_password
│   ├── wp_admin_password
│   └── wp_user_password
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── images_folder/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── entry/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── config/
        │   └── entry/
        └── wordpress/
            ├── Dockerfile
            └── entry/
```

> Secret files contain sensitive information and must never be committed to Git.

---

## Requirements & Design Constraints

The implementation follows the main constraints of the activity:

- The project is developed and executed inside a **Virtual Machine**.
- Docker Compose is used to orchestrate the infrastructure.
- Every service runs in its own dedicated container.
- Custom Dockerfiles are used for each service.
- The base distribution is Debian.
- NGINX provides the only external entry point.
- Only **port 443** is exposed publicly.
- NGINX supports TLS 1.2 and TLS 1.3.
- WordPress runs with PHP-FPM and does not contain NGINX.
- MariaDB runs independently from WordPress and NGINX.
- Services communicate through a dedicated Docker network.
- Persistent WordPress and database data are stored using Docker named volumes.
- Persistent data is stored under:

```text
/home/ialalawn/data/
```

- Containers are configured to restart after a crash.
- `network_mode: host`, `--link`, and legacy Docker links are not used.
- Hacky infinite-loop container keep-alive techniques such as `tail -f`, `sleep infinity`, or `while true` are not used.
- Passwords are not hard-coded in Dockerfiles.
- Configuration values are supplied through environment variables.
- Sensitive credentials are supplied through Docker Secrets.
- The WordPress database contains two users, including a WordPress administrator whose username does not contain `admin` or `administrator`.

---

# Core Design Decisions

## 1. Virtual Machines vs Docker

### Virtual Machines

A Virtual Machine virtualizes hardware through a hypervisor. Each VM has its own guest operating system and kernel.

```text
Physical Hardware
       │
   Hypervisor
       │
 ┌─────┴─────┐
 │           │
 VM 1       VM 2
 │           │
OS + App   OS + App
```

### Docker Containers

Docker provides operating-system-level isolation. Containers share the host kernel while isolating processes, networking, filesystems, and resources.

```text
Physical Hardware
       │
     Linux
       │
    Docker
 ┌─────┼─────┐
 │     │     │
NGINX  WP   MariaDB
```

Linux **namespaces** provide isolation, while **cgroups** control and account for resources.

### Why Docker?

For this project, Docker provides:

- Lightweight service isolation.
- Fast container startup.
- Reproducible environments.
- Independent service lifecycles.
- Clear separation of responsibilities.
- Simple networking between services.

The project itself still runs inside a VM because that is an explicit activity requirement.

---

## 2. Secrets vs Environment Variables

### Environment Variables

Environment variables are appropriate for non-sensitive configuration such as:

```text
MYSQL_DATABASE
MYSQL_USER
DOMAIN_NAME
HTTPS_PORT
WP_ADMIN
WP_ADMIN_EMAIL
WP_USER
WP_USER_EMAIL
```

They are convenient because Docker Compose can inject them into the container environment.

However, environment variables are not a secure mechanism for storing passwords. Depending on the environment, process information and container metadata can expose environment variables.

### Docker Secrets

Sensitive credentials are stored separately as secret files and mounted into containers under:

```text
/run/secrets/
```

Examples:

```text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

The application reads the secret when it needs the credential instead of hard-coding passwords inside Dockerfiles or source code.

### Design Choice

This project follows the separation:

```text
Non-sensitive configuration
        │
        ▼
   Environment
        │
        ├── Database name
        ├── Database user
        ├── Domain
        └── WordPress usernames/emails

Sensitive credentials
        │
        ▼
   Docker Secrets
        │
        ├── Database passwords
        └── WordPress passwords
```

This keeps credentials out of Dockerfiles and prevents passwords from being committed to the repository.

---

## 3. Docker Network vs Host Network

### Host Network

With host networking, a container shares the host's network namespace.

```text
Container
    │
    └── Host Network
```

This reduces network isolation and can create port conflicts or expose services more directly.

### User-Defined Docker Network

This project uses a dedicated Docker bridge network:

```text
                 src_back_net
          ┌──────────┼──────────┐
          │          │          │
        NGINX     WordPress   MariaDB
```

Docker provides internal DNS resolution, allowing services to communicate using service names.

For example:

```text
wordpress → mariadb:3306
nginx     → wordpress:9000
```

### Design Choice

Only NGINX publishes a host port:

```text
Host :443 → NGINX :443
```

MariaDB and PHP-FPM remain internal to the Docker network.

This creates a clear network boundary between the public entry point and internal services.

---

## 4. Docker Volumes vs Bind Mounts

### Docker Named Volumes

Named volumes are managed by Docker and referenced by name:

```yaml
volumes:
  wordpress_data:
  mariadb_data:
```

They decouple persistent application data from the lifecycle of individual containers.

### Host Storage Requirement

The activity requires the persistent data to be available under:

```text
/home/ialalawn/data/
```

The project therefore uses **Docker named volumes configured with host-backed storage options** so that Docker still manages the volume while the underlying persistent data remains available at the required host location.

Conceptually:

```text
Docker Named Volume
        │
        ▼
/home/ialalawn/data/
   ├── wordpress/
   └── mariadb/
```

This provides persistence across container recreation while keeping the storage location explicit and auditable on the host.

---

# Prerequisites

Before starting the project, make sure the VM has:

- Linux environment.
- `make`
- Docker Engine
- Docker Compose v2 (`docker compose`)
- `sudo` privileges or appropriate Docker permissions.

Verify:

```bash
docker --version
docker compose version
make --version
```

---

# Configuration

## Environment Variables

Create:

```text
srcs/.env
```

Example:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

DOMAIN_NAME=ialalawn.42.fr
HTTPS_PORT=443

WP_ADMIN=your_admin_username
WP_ADMIN_EMAIL=admin@example.com

WP_USER=your_second_user
WP_USER_EMAIL=user@example.com
```

Do **not** put passwords in `.env`.

The variable names used by the project must remain consistent with the Docker Compose and initialization scripts.

---

## Docker Secrets

Create the required secret files inside:

```text
secrets/
```

Example:

```text
secrets/
├── db_password.txt
├── db_root_password.txt
├── wp_admin_password.txt
└── wp_user_password.txt
```

Each file should contain only the corresponding secret value.

Example:

```bash
printf '%s\n' 'your-password' > secrets/db_password.txt
```

Protect the files:

```bash
chmod 600 secrets/*.txt
```

Make sure they are excluded from Git:

```gitignore
secrets/
```

---

## Domain Configuration

The required domain format is:

```text
<login>.42.fr
```

For this project:

```text
ialalawn.42.fr
```

For local testing, map the domain to the machine hosting the infrastructure.

Example:

```bash
echo "127.0.0.1 ialalawn.42.fr" | sudo tee -a /etc/hosts
```

If Docker is running inside a VM and the website is accessed from another machine, map the domain to the VM's reachable IP address instead.

---

# Build & Run

The recommended entry point is the Makefile.

Build and start the complete infrastructure:

```bash
make
```

or:

```bash
make up
```

Check the running containers:

```bash
make ps
```

Follow the logs:

```bash
make logs
```

---

# Makefile Commands

| Command | Purpose |
|---|---|
| `make` / `make up` | Build and start the infrastructure |
| `make ps` | Show container status |
| `make logs` | Follow service logs |
| `make stop` | Stop running containers |
| `make start` | Start stopped containers |
| `make clean` | Remove containers, networks, and Docker volume registrations while preserving host data |
| `make fclean` | Full reset: remove infrastructure and persistent project data |
| `make re` | Rebuild the infrastructure from scratch |

### Clean vs Full Clean

`make clean` is intended to preserve:

```text
/home/ialalawn/data/
```

This means application and database data can survive container recreation.

`make fclean` is destructive. It is intended for a complete project reset and removes persistent WordPress and MariaDB data from the host.

---

# Accessing the Application

After starting the infrastructure, verify:

```bash
make ps
```

Then access:

### WordPress Website

```text
https://ialalawn.42.fr
```

### WordPress Administration

```text
https://ialalawn.42.fr/wp-login.php
```

The browser may display a certificate warning during local development because the TLS certificate is locally generated rather than issued by a public Certificate Authority.

---

# Service Responsibilities

## NGINX

NGINX is the public-facing reverse proxy.

Responsibilities:

- Accept HTTPS traffic.
- Enforce TLS 1.2/1.3.
- Serve as the only external entry point.
- Forward PHP requests to PHP-FPM.
- Keep internal services inaccessible from the host network.

NGINX communicates with WordPress through FastCGI.

---

## WordPress + PHP-FPM

The WordPress container is responsible for:

- WordPress core.
- PHP runtime.
- PHP-FPM.
- WordPress configuration.
- WordPress initialization.
- Communication with MariaDB.

The container does **not** contain NGINX.

---

## MariaDB

MariaDB is responsible exclusively for:

- WordPress database storage.
- Database initialization.
- Database users and privileges.
- Persistent relational data.

MariaDB is not exposed directly to the host.

---

# Data Persistence

There are two persistent data stores:

```text
/home/ialalawn/data/
├── mariadb/
└── wordpress/
```

### MariaDB Data

Contains the WordPress database and MariaDB system data.

### WordPress Data

Contains WordPress application files, themes, plugins, uploads, and other website data.

Containers can be destroyed and recreated without losing persistent data, provided the host data directory is preserved.

---

# Networking & Security

## Public Exposure

Only:

```text
443/tcp
```

is exposed to the outside.

Internal ports such as:

```text
3306  → MariaDB
9000  → PHP-FPM
```

are used for container-to-container communication and are not published to the host.

## TLS

NGINX is configured to allow only:

```text
TLSv1.2
TLSv1.3
```

## Database Isolation

MariaDB is reachable through the Docker network rather than directly from the public interface.

WordPress connects using the service name:

```text
mariadb:3306
```

Docker's internal DNS resolves the service name to the appropriate container.

## Credential Management

Passwords are not stored in:

- Dockerfiles
- application source code
- `.env`
- Git history

Sensitive values are provided through Docker Secrets.

---

# Troubleshooting

## Check Container Status

```bash
docker compose ps
```

or:

```bash
make ps
```

## View All Logs

```bash
docker compose logs
```

## Follow MariaDB Logs

```bash
docker compose logs -f mariadb
```

## Follow WordPress Logs

```bash
docker compose logs -f wordpress
```

## Follow NGINX Logs

```bash
docker compose logs -f nginx
```

## Enter a Running Container

```bash
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash
```

## Inspect Volumes

```bash
docker volume ls
docker volume inspect <volume_name>
```

## Inspect the Docker Network

```bash
docker network ls
docker network inspect <network_name>
```

## Test Internal DNS

From the WordPress container:

```bash
getent hosts mariadb
```

## Test Database Connectivity

From WordPress:

```bash
mariadb -h mariadb -u"$MYSQL_USER" -p"$DB_PASSWORD" "$MYSQL_DATABASE"
```

The exact credential source should follow the project's secret-handling implementation.

---

# Useful Docker Commands

### Rebuild Without Cache

```bash
docker compose build --no-cache
```

### Recreate Containers

```bash
docker compose up -d --build --force-recreate
```

### Stop and Remove Containers

```bash
docker compose down
```

### Remove Containers and Compose Volumes

```bash
docker compose down -v
```

> Use `-v` carefully because it removes Docker-managed named volumes. Always understand whether the volume configuration preserves the required host data before using it.

### Complete Docker Inspection

```bash
docker ps -a
docker images
docker volume ls
docker network ls
```

---

# Resources

## References & Learning Materials

### Docker Essentials & DevOps Foundations

**Learn Docker – Full DevOps Course for Deploying Containerized Apps (freeCodeCamp)**

Foundational material covering containerization principles, the transition from bare-metal servers and virtual machines to containers, practical container deployment patterns on AWS EC2, image layers, and storage foundations.

### Docker Compose Orchestration

**Ultimate Docker Compose Tutorial (TechWorld with Nana)**

Practical material covering multi-container orchestration, microservice architectures, service dependency resolution, networking mechanisms, and environment decoupling.

### Reference Implementation

**noorhanalayyoub/Inception Repository**

Used as a structural reference for 42 Inception requirements, documentation standards, and script architecture.

### Official Technical Documentation

- **Docker Documentation:** Compose Specification
- **MariaDB Server Knowledge Base:** Server System Variables & CLI Administration
- **NGINX Documentation:** Configuring HTTPS Servers
- **WP-CLI Command Reference:** Core Install & User Management

---

## AI Usage & Assistance Transparency

Artificial Intelligence (AI) was used throughout this project as a pair-programming, troubleshooting, and architectural consultation partner.

AI assistance was used for:

- **MariaDB Initialization Flow:** Troubleshooting MariaDB authentication errors, including Errors 1045 and 1130, and reviewing the database initialization flow.
- **Host Bind-Mount State Debugging:** Diagnosing directory detection issues where Debian packages populate `/var/lib/mysql` during image build time, and reviewing first-boot detection logic.
- **Makefile Optimization:** Structuring lifecycle workflows such as `clean`, `fclean`, and `re`, including safe command execution patterns.

AI-generated suggestions were reviewed, tested, and adapted to the actual project implementation. The final implementation remains the responsibility of the project author, who must understand and be able to explain the code and design decisions during evaluation.

---

# Author

**ialalawn**

42 Network — Inception
