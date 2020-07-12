DATABASE ?= philomena
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=comments.jsonl --output=http://localhost:9200/ --output-index=comments --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc)"

dump_jsonl: metadata authors tags
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_comments.jsonb_object_agg(object) from temp_comments.comment_search_json group by comment_id) to stdout;' > comments.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_comments cascade;'
	sed -i comments.jsonl -e 's/\\\\/\\/g'

metadata: comment_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_comments.comment_search_json (comment_id, object) select c.id, jsonb_build_object(
			'id', c.id,
			'posted_at', c.created_at,
			'ip', c.ip,
			'fingerprint', c.fingerprint,
			'image_id', c.image_id,
			'user_id', c.user_id,
			'anonymous', c.anonymous,
			'body', c.body,
			'hidden_from_users', (c.hidden_from_users or i.hidden_from_users)
		) from comments c inner join images i on c.image_id=i.id;
	SQL

authors: comment_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_comments.comment_search_json (comment_id, object) select c.id, jsonb_build_object('author', (case when c.anonymous='t' then null else u.name end)) from comments c left join users u on c.user_id=u.id;
	SQL

tags: comment_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		create unlogged table temp_comments.image_tags (image_id bigint not null, tags jsonb not null);
		insert into temp_comments.image_tags (image_id, tags) select it.image_id, jsonb_agg(it.tag_id) from image_taggings it group by it.image_id;
		insert into temp_comments.comment_search_json (comment_id, object) select c.id, jsonb_build_object('image_tag_ids', it.tags) from comments c inner join temp_comments.image_tags it on c.image_id=it.image_id;
	SQL

comment_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_comments cascade;
		create schema temp_comments;
		create unlogged table temp_comments.comment_search_json (comment_id bigint not null, object jsonb not null);
		create or replace aggregate temp_comments.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
