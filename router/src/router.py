#!/usr/bin/env python3

"""HTTP API handler for routing requests to KV store."""

from flask import Flask, jsonify, make_response, request, Response
from http import HTTPStatus
import logging
import re
import sys

APP = Flask(__name__)

logging.basicConfig(
        stream=sys.stdout,
        level=logging.INFO,
        format="%(asctime)s - %(module)s - %(funcName)s - %(levelname)s - %(message)s",
)
LOG = logging.getLogger(__name__)

VALID_CHARSET = re.compile("[a-z-0-9]+")

KV = {}


@APP.route("/set", methods=["POST"])
def set() -> Response:
    """Handler for setting KV pair."""
    key = request.form.get("key")
    if not is_valid_string(key):
        msg = f"invalid key {key!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)

    value = request.form.get("value")
    if not is_valid_string(value):
        msg = f"invalid value {value!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)

    if key not in KV:
        KV[key] = value
        action, code = 'created', HTTPStatus.CREATED
    elif KV[key] != value:
        KV[key] = value
        action, code = 'updated', HTTPStatus.NO_CONTENT
    else:
        action, code = 'unchanged', HTTPStatus.NOT_MODIFIED

    msg = f"{action} key:value {key!r}:{value!r}"
    return json_response(msg, code)


@APP.route("/get/<string:key>")
def get(key: str) -> Response:
    """Handler for getting value for given key."""
    if not is_valid_string(key):
        msg = f"invalid key {key!r}"
        return json_response(msg, HTTPStatus.BAD_REQUEST)
    
    if value := KV.get(key) is None:
        msg = f"key not found {key!r}"
        return json_response(msg, HTTPStatus.NOT_FOUND)
    else:
        return make_response(jsonify({"value": value}), HTTPStatus.OK)


@APP.route("/search")
def search() -> Response:
    """Handler for searching keys by prefix and/or suffix."""
    prefix = request.args.get("prefix")
    suffix = request.args.get("suffix")

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

    results = {}

    if do_prefix:
        pfx_list = []
        for key in KV:
            if key.startswith(prefix):
                pfx_list.append(key)
        results["prefix"] = pfx_list

    if do_suffix:
        sfx_list = []
        for key in KV:
            if key.endswith(suffix):
                sfx_list.append(key)
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


if __name__ == "__main__":
    APP.run(debug=True, port=5000)

