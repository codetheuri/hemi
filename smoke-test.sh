#!/bin/sh
# Smoke test a built hemi image. Used by CI before pushing; run locally with:
#   docker build -t hemi:test . && ./smoke-test.sh hemi:test
set -eu

IMAGE="${1:?usage: $0 <image>}"
EXTENSIONS="bcmath exif gd intl mbstring mysqli opcache pdo_mysql pdo_pgsql soap xml zip redis"
NAME="hemi-smoke-$$"
fail=0

echo "--- PHP extensions"
modules=$(docker run --rm "$IMAGE" php -m 2>&1)
if echo "$modules" | grep -iqE 'warning|error'; then
    echo "php -m reported startup problems:"; echo "$modules"; fail=1
fi
for ext in $EXTENSIONS; do
    name=$ext
    [ "$ext" = opcache ] && name="Zend OPcache"
    echo "$modules" | grep -qix "$name" || { echo "missing PHP extension: $ext"; fail=1; }
done

echo "--- Config tests and tools"
docker run --rm "$IMAGE" sh -ec '
    nginx -t
    php-fpm -t
    composer --version
    git --version
    zip -v >/dev/null
    unzip -v >/dev/null
' || fail=1

echo "--- Container becomes healthy (nginx -> php-fpm)"
docker run -d --name "$NAME" --health-interval=2s "$IMAGE" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1' EXIT
status=starting
for _ in $(seq 1 30); do
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$NAME")
    [ "$status" = starting ] || break
    sleep 2
done
echo "health: $status"
if [ "$status" != healthy ]; then
    docker logs "$NAME"; fail=1
fi

[ "$fail" -eq 0 ] && echo "smoke test passed" || echo "smoke test FAILED"
exit "$fail"
