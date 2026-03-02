# this script should be run from the root of
# the veery_old repository

source .venv/bin/activate
cd model
oneil eval radar.on --print-mode all --no-header --no-test-report
oneil test radar.on --no-header --recursive