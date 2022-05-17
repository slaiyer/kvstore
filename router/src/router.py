#!/usr/bin/env python3

"""HTTP API handler for routing requests to KV store."""

from flask import Flask, jsonify, make_response, request, Response
from http import HTTPStatus
from prometheus_flask_exporter import PrometheusMetrics
import logging
import os
import re
import redis
import sys

APP = Flask(__name__)
METRICS = PrometheusMetrics(
        APP,
        group_by="endpoint",
        default_latency_as_histogram=False,
)

logging.basicConfig(
        stream=sys.stdout,
        level=logging.INFO,
        format="%(asctime)s - %(module)s - %(funcName)s - %(levelname)s - %(message)s",
)
LOG = logging.getLogger(__name__)

REDIS_PASSWORD = os.getenv("REDIS_PASSWORD")
REDIS_RW_HOST = os.getenv("REDIS_RW_HOST", "localhost")
REDIS_RW_PORT = os.getenv("REDIS_RW_PORT", "6379")
REDIS_RW = redis.Redis(
        host=REDIS_RW_HOST,
        port=int(REDIS_RW_PORT),
        password=REDIS_PASSWORD,
        decode_responses=True,
)
LOG.info("redis rw host ping success: %s", REDIS_RW.ping())
REDIS_RO_HOST = os.getenv("REDIS_RO_HOST", REDIS_RW_HOST)
REDIS_RO_PORT = os.getenv("REDIS_RO_PORT", REDIS_RW_PORT)
if REDIS_RO_HOST == REDIS_RW_HOST and REDIS_RO_PORT == REDIS_RW_PORT:
    REDIS_RO = REDIS_RW
else:
    REDIS_RO = redis.Redis(
            host=REDIS_RO_HOST,
            port=int(REDIS_RO_PORT),
            password=REDIS_PASSWORD,
            decode_responses=True,
    )
    LOG.info("redis ro host ping success: %s", REDIS_RO.ping())

VALID_CHARSET = re.compile("[a-z-0-9]+")


@APP.route("/set", methods=["POST"])
def set() -> Response:
    """Handler for setting KV pair."""
    key = request.form.get("key")
    if key is None or not is_valid_string(key):
        msg = f"invalid key {key!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)

    value = request.form.get("value")
    if value is None or not is_valid_string(value):
        msg = f"invalid value {value!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)

    if (old_value := REDIS_RW.set(key, value, get=True)) is None:
        action, code = 'created', HTTPStatus.CREATED
    else:
        action, code = 'updated', HTTPStatus.OK

    msg = f"{action} key:value {key!r}:{value!r}"
    return json_response(msg, code)


@APP.route("/get/<string:key>")
def get(key: str) -> Response:
    """Handler for getting value for given key."""
    if key is None or not is_valid_string(key):
        msg = f"invalid key {key!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)
    
    if (value := REDIS_RO.get(key)) is None:
        msg = f"key not found {key!r}"
        return json_response(msg, HTTPStatus.NOT_FOUND)
    else:
        return make_response(jsonify({"value": value}), HTTPStatus.OK)


@APP.route("/search")
def search() -> Response:
    """Handler for searching keys by prefix and/or suffix."""
    prefix = request.args.get("prefix")
    suffix = request.args.get("suffix")

    # BEGIN INPUT VALIDATION

    if prefix is None and suffix is None:
        return json_response("no search params", HTTPStatus.BAD_REQUEST)

    msgs = []
    do_prefix = False
    do_suffix = False

    if prefix is None:
        pass
    elif not is_valid_string(prefix):
        msgs.append("invalid prefix")
    else:
        do_prefix = True

    if suffix is None:
        pass
    elif not is_valid_string(suffix):
        msgs.append("invalid suffix")
    else:
        do_suffix = True
    
    msg = ', '.join(msgs)
    if not (do_prefix or do_suffix):
        return json_response(msg, HTTPStatus.BAD_REQUEST)

    # END INPUT VALIDATION

    results = {}
    pfx_list = []
    sfx_list = []
    for key in REDIS_RO.scan_iter():
        if do_prefix and key.startswith(prefix):
            pfx_list.append(key)
        if do_suffix and key.endswith(suffix):
            sfx_list.append(key)
    if do_prefix:
        results["prefix"] = pfx_list
    if do_suffix:
        results["suffix"] = sfx_list

    response: dict[str, object] = {}
    if msg:
        response["msg"] = msg
    response["results"] = results
    return make_response(jsonify(response), HTTPStatus.OK)
    

def is_valid_string(input: str) -> bool:
    """Helper for validating input against defined slug regex."""
    result = bool(VALID_CHARSET.fullmatch(input))
    if not result:
        LOG.warning("invalid input %s", repr(input))
    return result


def json_response(msg: str, code: int) -> Response:
    """Wrapper for creating JSON response with status code."""
    return make_response(jsonify({"msg": msg}), code)


METRICS.register_default(
    METRICS.gauge(
        "num_keys_gauge", "Number of keys in Redis",
        labels={"num_keys": lambda: REDIS_RO.dbsize()}
    ),
)
