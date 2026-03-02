#!/usr/bin/env bash
set -euxo pipefail

# this script should be run from the root of
# the veery_old repository

source .venv/bin/activate
cd model
oneil regression-test radar.on > "${original_dir}/old.out" 2>&1
