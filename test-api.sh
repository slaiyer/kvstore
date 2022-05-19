#!/usr/bin/env bash

inso --verbose --ci --src test/requests.json run test -e kvstore kvstore-expected
