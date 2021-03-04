#!/bin/bash

if [[ -z "${TEST}" ]]; then
  crystal src/sequin.cr --error-trace
else
  crystal spec -v --error-trace

  tail -f /dev/null
fi
