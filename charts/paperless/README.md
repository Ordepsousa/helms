# Paperless NGX Helm chart

Deploys Paperless NGX as three workloads:

| Workload    | Purpose                                                      | Scaling                      |
|-------------|--------------------------------------------------------------|------------------------------|
| `core`      | Migrations, document consumer, scheduler, Tika and Gotenberg | Always 1 replica, `Recreate` |
| `webserver` | web UI                                                       | Configurable                 |
| `worker`    | Celery task processing                                       | Configurable                 |

## Requirements

- Kubernetes and Helm 3
- A StorageClass, or existing PVCs
- A secure secret key

PostgreSQL and Dragonfly are bundled by default. Both can be disabled in favor of external services.

> [!WARNING]
> SQLite is supported for minimal installations, but requires the data persistent volume across workloads. It is **strongly discouraged** for production or multi-replica environments due to database
locking and lack of high availability.

## Minimal values

```yaml
config:
    domain: https://paperless.example.com
    secretKey: replace-with-a-random-secret # e.g., openssl rand -base64 32
```

> [!TIP]
> `config.secretKey` is empty by default. Generate it externally or use `config.existingSecret` referencing a pre-created Kubernetes Secret.

## Scaling

Configure replicas and update strategies independently:

```yaml
webserver:
    replicaCount: 2
    strategy:
        type: RollingUpdate

worker:
    replicaCount: 4
    strategy:
        type: RollingUpdate
```

*Note: The `core` workload scaling parameters are hard-coded in the chart templates to prevent race conditions during database migrations and document ingestion.*

## Database and broker

The default mode is `auto`:

- **Database:** Bundled PostgreSQL (falls back to SQLite if PostgreSQL is disabled).
- **Broker:** Bundled Dragonfly.

To use external services, set `config.database.mode: external` or `config.redis.mode: external`, then provide the connection parameters under each respective section.

*Note: `config.redis.external` supports Redis, Valkey, and Dragonfly; `config.database.external` supports PostgreSQL, MariaDB/MySQL.*

## Ingress and Gateway API

Traditional Ingress is disabled by default. Enable it via:

```yaml
ingress:
    enabled: true
    className: nginx
```

For modern Gateway API implementations, configure an `HTTPRoute` instead:

```yaml
httproute:
    enabled: true
    parentRefs:
        -   name: public-gateway
```

*Gateway API takes precedence over Ingress if both flags are enabled simultaneously.*

## Installation

Update dependencies and deploy the chart:

```bash
helm dependency update ./charts/paperless
helm install paperless ./charts/paperless -f values.yaml
```

### Local Validation

```bash
helm lint ./charts/paperless
helm unittest ./charts/paperless
```

## Probes & Health Checks

The chart implements targeted application-level health tracking:

- **Webserver, Gotenberg, Tika:** Active HTTP liveness and readiness probes.
- **Consumer, Scheduler, Worker:** Monitored as PID 1 long-running processes; Kubernetes handles restarts automatically upon exit.