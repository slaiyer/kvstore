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

REDIS_HOST = os.getenv("REDIS_SERVICE_HOST", "localhost")
REDIS_PORT = os.getenv("REDIS_SERVICE_PORT", "6379")
REDIS = redis.Redis(host=REDIS_HOST, port=int(REDIS_PORT), decode_responses=True)
LOG.info("redis host ping success: %s", REDIS.ping())

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

    if (old_value := REDIS.set(key, value, get=True)) is None:
        action, code = 'created', HTTPStatus.CREATED
    else:
        action, code = 'updated', HTTPStatus.OK

    msg = f"{action} key:value {key!r}:{value!r}"
    return json_response(msg, code)


@APP.route("/get/<string:key>")
#@METRICS.gauge(
#    "num_keys_gauge", "Number of keys in Redis",
#    labels={"num_keys": lambda: REDIS.dbsize()}
#)
def get(key: str) -> Response:
    """Handler for getting value for given key."""
    if key is None or not is_valid_string(key):
        msg = f"invalid key {key!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)
    
    if (value := REDIS.get(key)) is None:
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
    for key in REDIS.scan_iter():
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
        labels={"num_keys": lambda: REDIS.dbsize()}
    )
)


if __name__ == "__main__":
    APP.run(debug=True, port=5000)

