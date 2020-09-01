#!/bin/sh

MAX_AGE=${MAX_SOURCE_CHANGE_AGE:-14d};

echo "Anonimizing source changes that are older than ${MAX_AGE}"
psql -c "UPDATE tag_changes SET ip = '0.0.0.0', fingerprint = '', user_agent = '', referrer = '' where created_at < NOW() - INTERVAL '${MAX_AGE}' and IP != '0.0.0.0' RETURNING id"
