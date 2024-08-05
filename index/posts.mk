DATABASE ?= philomena
OPENSEARCH_URL ?= http://localhost:9200/
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=posts.jsonl --output=$OPENSEARCH_URL --output-index=posts --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc); doc._id = doc.id"

dump_jsonl: metadata authors
	psql $(DATABASE) -v ON_ERROR_STOP=1 -c 'copy (select temp_posts.jsonb_object_agg(object) from temp_posts.post_search_json group by post_id) to stdout;' > posts.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 -c 'drop schema temp_posts cascade;'
	sed -i posts.jsonl -e 's/\\\\/\\/g'

metadata: post_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_posts.post_search_json (post_id, object) select p.id, jsonb_build_object(
			'id', p.id,
			'topic_id', p.topic_id,
			'body', p.body,
			'subject', t.title,
			'ip', p.ip,
			'user_agent', '',
			'referrer', '',
			'fingerprint', p.fingerprint,
			'topic_position', p.topic_position,
			'forum', f.short_name,
			'forum_id', t.forum_id,
			'user_id', p.user_id,
			'anonymous', p.anonymous,
			'created_at', p.created_at,
			'updated_at', p.updated_at,
			'deleted', p.hidden_from_users,
			'destroyed_content', p.destroyed_content,
			'access_level', f.access_level
		) from posts p inner join topics t on t.id=p.topic_id inner join forums f on f.id=t.forum_id;
	SQL

authors: post_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_posts.post_search_json (post_id, object) select p.id, jsonb_build_object('author', (case when p.anonymous='t' then null else u.name end)) from posts p left join users u on p.user_id=u.id;
	SQL

post_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_posts cascade;
		create schema temp_posts;
		create unlogged table temp_posts.post_search_json (post_id bigint not null, object jsonb not null);
		create or replace aggregate temp_posts.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
