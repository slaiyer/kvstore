# kvstore

Uses [kind](https://github.com/kubernetes-sigs/kind) to set up a local Kubernetes cluster for running a highly available service accessible via HTTP that interacts with a key-value store over the network.

## Components

- Redis as key-value store
  - Master-slave configuration
    - 1 x read-write master
    - 3 x read-only slaves
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
  - API correctness blackbox tests
  - API load tests
    - Also during rolling redeployment

## Common operations in order

> For maximum performance, consider: ``alias make='make -j`nproc`'``

- `make`: sets up cluster end to end
  - Fails fast if required tools are not available on `PATH`
- `make test-deploy-rollout`
  - Runs API test suite and populates Redis
    - [Optional] `make connect-redis`: forwards Redis to local port and logs in
  - Starts API load test suite
  - Concurrently initiates redeployment rollout with image variant having same functionality
  - `make view-fortio-reports`: launches local web UI for viewing load testing reports
- `make forward-prometheus`: forwards Prometheus to local port
  - Endpoint latency buckets: `sum(http_request_duration_seconds_bucket{handler!~"/(healthz|metrics).*"}) by(handler, le)`
  - HTTP status codes from endpoints: `sum(http_requests_total{handler!~"/(healthz|metrics).*"}) by(handler, method, status)`
  - Number of keys in DB: `sum(redis_db_keys{db="db0"}) by(db)`
- `make teardown`: destroys cluster
