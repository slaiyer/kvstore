# kvstore

Uses [kind](https://github.com/kubernetes-sigs/kind) to set up a local Kubernetes cluster for running a highly available service accessible via HTTP that interacts with a key-value store over the network.

## Components

- Redis as key-value store
  - Master-slave configuration
    - 1 x read-write master
    - 3x read-only slaves
- `router` as HTTP API server
  - Stack: Python, FastAPI, uvicorn
  - `/set` talks to Redis master
  - `/get`, `/search` talk to Redis slaves
  - `/metrics` exposes basic HTTP related data
- Prometheus
  - Scrapes Redis and `router`
- Ingress
  - Routes incoming traffic at port `8080` to `router`
- `router` tests
  - Blackbox API correctness tests
  - API load tests

## Common operations in order

> For maximum speed: ``alias make='make -j`nproc`'``

- `make`: sets up everything end to end
  - Fast fails if required tools are not available on `PATH`
- `make test-deploy-rollout`
  - Runs API test suite to populate Redis
    - [Optional] `make connect-redis`: forwards Redis to local port and logs in
  - Starts API load test suite
  - Initiates redeployment rollout with image variant having same functionality
  - `make view-fortio-reports`: launches local web UI for viewing load testing reports
- `make forward-prometheus`: forwards Prometheus to local port
  - Endpoint latency buckets: `sum(http_request_duration_seconds_bucket{handler!~"/(healthz|metrics).*"}) without(instance, job)`
  - HTTP status codes from endpoints: `sum(http_requests_total{handler!~"/(healthz|metrics).*"}) without(instance, job)`
  - Number of keys in DB: `sum(redis_db_keys{db="db0"}) without(instance, job)`
- `make teardown`: destroys kind cluster

## Useful, but out of scope

- No Redis persistence, sentinel
