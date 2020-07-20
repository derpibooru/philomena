#!/bin/sh

if [[ -z "${MAX_AGE}" ]]; then
  MAX_IMAGE_AGE='14d'
else
  MAX_IMAGE_AGE="${MAX_AGE}"
fi

echo "Anonymized IPs for images with id that are older than ${MAX_IMAGE_AGE}"
psql -c "UPDATE images SET ip = '0.0.0.0' where created_at < NOW() - INTERVAL '${MAX_IMAGE_AGE}' and IP != '0.0.0.0' RETURNING id"
