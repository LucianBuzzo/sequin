#!/bin/bash

if [[ -z "${TEST}" ]]; then
  crystal spec -v --error-trace

  tail -f /dev/null
else
  crystal src/sequin.cr
fi
