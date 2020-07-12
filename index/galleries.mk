DATABASE ?= philomena
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=galleries.jsonl --output=http://localhost:9200/ --output-index=galleries --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc)"

dump_jsonl: metadata subscribers images
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_galleries.jsonb_object_agg(object) from temp_galleries.gallery_search_json group by gallery_id) to stdout;' > galleries.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_galleries cascade;'
	sed -i galleries.jsonl -e 's/\\\\/\\/g'

metadata: gallery_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_galleries.gallery_search_json (gallery_id, object) select g.id, jsonb_build_object(
			'id', g.id,
			'image_count', g.image_count,
			'updated_at', g.updated_at,
			'created_at', g.created_at,
			'title', lower(g.title),
			'creator', lower(u.name),
			'description', g.description
		) from galleries g left join users u on g.creator_id=u.id;
	SQL

subscribers: gallery_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_galleries.gallery_search_json (gallery_id, object) select gallery_id, json_build_object('watcher_ids', jsonb_agg(user_id), 'watcher_count', count(*)) from gallery_subscriptions group by gallery_id;
	SQL

images: gallery_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_galleries.gallery_search_json (gallery_id, object) select gallery_id, json_build_object('image_ids', jsonb_agg(image_id)) from gallery_interactions group by gallery_id;
	SQL

gallery_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_galleries cascade;
		create schema temp_galleries;
		create unlogged table temp_galleries.gallery_search_json (gallery_id bigint not null, object jsonb not null);
		create or replace aggregate temp_galleries.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
