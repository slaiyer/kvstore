#!/usr/bin/env python3

"""HTTP API handler for routing requests to KV store."""

import os

from fastapi import FastAPI, Path, Query, Response, status
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field
from redis import Redis

APP = FastAPI()

REDIS_PASSWORD = os.getenv("redis-password")
REDIS_RW_PORT = os.getenv("REDIS_MASTER_SERVICE_PORT", "6379")
REDIS_RW = Redis(
        host="redis-master",
        port=int(REDIS_RW_PORT),
        password=REDIS_PASSWORD,
        decode_responses=True,
)
REDIS_RO_PORT = os.getenv("REDIS_REPLICAS_SERVICE_PORT", REDIS_RW_PORT)
REDIS_RO = Redis(
        host="redis-replicas",
        port=int(REDIS_RO_PORT),
        password=REDIS_PASSWORD,
        decode_responses=True,
)


@APP.get("/healthz/live")
def liveness():
    return {"status": "OK"}


@APP.get("/healthz/ready")
def readiness(response: Response):
    if not ((redis_rw := REDIS_RW.ping()) and (redis_ro := REDIS_RO.ping())):
        response.status_code = status.HTTP_502_BAD_GATEWAY
        return {"status": f"reachable: redis-master={redis_rw}, redis-replica={redis_ro}"}

    return {"status": "OK"}

VALID_CHARSET = "^[a-z-0-9]+$"


class KVPair(BaseModel):
    key: str = Field(regex=VALID_CHARSET)
    value: str = Field(regex=VALID_CHARSET)


@APP.post("/set")
def set(
        response: Response,
        kv_pair: KVPair,
):
    """Handler for setting KV pair."""
    if REDIS_RW.set(kv_pair.key, kv_pair.value, get=True) is None:
        response.status_code = status.HTTP_201_CREATED

    return {"msg": f"set {kv_pair.key!r}: {kv_pair.value!r}"}


@APP.get("/get/{key}")
def get(
        response: Response,
        key: str = Path(regex=VALID_CHARSET),
):
    """Handler for getting value for given key."""
    if (value := REDIS_RO.get(key)) is None:
        response.status_code = status.HTTP_404_NOT_FOUND
        return {"msg": f"key not found {key!r}"}
    else:
        return {"value": value}


@APP.get("/search")
def search(
        response: Response,
        prefix: str | None = Query(default=None, regex=VALID_CHARSET),
        suffix: str | None = Query(default=None, regex=VALID_CHARSET),
):
    """Handler for searching keys by prefix and/or suffix."""
    if prefix is None and suffix is None:
        response.status_code = status.HTTP_400_BAD_REQUEST
        return {"msg": "no search params"}

    results = {}
    pfx_list = []
    sfx_list = []
    for key in REDIS_RO.scan_iter():
        if prefix and key.startswith(prefix):
            pfx_list.append(key)
        if suffix and key.endswith(suffix):
            sfx_list.append(key)
    if prefix:
        results["prefix"] = pfx_list
    if suffix:
        results["suffix"] = sfx_list

    return {"results": results}


Instrumentator().instrument(APP).expose(APP)
