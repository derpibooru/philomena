DATABASE ?= philomena
ELASTICSEARCH_URL ?= http://localhost:9200/
ELASTICDUMP ?= elasticdump
# uncomment if getting "redirection unexpected" error on dump_jsonl
#SHELL=/bin/bash

.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=filters.jsonl --output=$(ELASTICSEARCH_URL) --output-index=filters --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc); doc._id = doc.id"

dump_jsonl: metadata creators
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_filters.jsonb_object_agg(object) from temp_filters.filter_search_json group by filter_id) to stdout;' > filters.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_filters cascade;'
	sed -i filters.jsonl -e 's/\\\\/\\/g'

metadata: filter_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_filters.filter_search_json (filter_id, object) select f.id, jsonb_build_object(
			'id', f.id,
			'created_at', f.created_at,
			'user_id', f.user_id,
			'public', f.public or f.system,
			'system', f.system,
			'name', lower(f.name),
			'description', f.description,
			'spoilered_count', array_length(f.spoilered_tag_ids, 1),
			'hidden_count', array_length(f.hidden_tag_ids, 1),
			'spoilered_tag_ids', f.spoilered_tag_ids,
			'hidden_tag_ids', f.hidden_tag_ids,
			'spoilered_complex_str', lower(f.spoilered_complex_str),
			'hidden_complex_str', lower(f.hidden_complex_str),
			'user_count', f.user_count
		) from filters f;
	SQL

creators: filter_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_filters.filter_search_json (filter_id, object) select f.id, jsonb_build_object('creator', lower(u.name)) from filters f left join users u on f.user_id=u.id;
	SQL

filter_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_filters cascade;
		create schema temp_filters;
		create unlogged table temp_filters.filter_search_json (filter_id bigint not null, object jsonb not null);
		create or replace aggregate temp_filters.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
