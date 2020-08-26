#!/bin/sh

MAX_AGE=${MAX_COMMENT_AGE:-14d};

echo "Anonimizing comments that are older than ${MAX_AGE}"
psql -c "UPDATE comments SET ip = '0.0.0.0', referrer = '', user_agent = '' where created_at < NOW() - INTERVAL '${MAX_AGE}' and IP != '0.0.0.0' RETURNING id"
