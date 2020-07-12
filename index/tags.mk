DATABASE ?= philomena
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=tags.jsonl --output=http://localhost:9200/ --output-index=tags --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc)"

dump_jsonl: metadata aliases implied_tags implied_by_tags
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_tags.jsonb_object_agg(object) from temp_tags.tag_search_json group by tag_id) to stdout;' > tags.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_tags cascade;'
	sed -i tags.jsonl -e 's/\\\\/\\/g'

metadata: tag_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_tags.tag_search_json (tag_id, object) select t.id, jsonb_build_object(
			'id', t.id,
			'slug', t.slug,
			'name', t.name,
			'name_in_namespace', t.name_in_namespace,
			'namespace', t.namespace,
			'analyzed_name', t.name,
			'aliased_tag', at.name,
			'category', t.category,
			'aliased', (t.aliased_tag_id is not null),
			'description', t.description,
			'short_description', t.short_description
		) from tags t left join tags at on t.aliased_tag_id=at.id;
	SQL

aliases: tag_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_tags.tag_search_json (tag_id, object) select t.aliased_tag_id, jsonb_build_object('aliases', jsonb_agg(t.name)) from tags t inner join tags at on t.aliased_tag_id=t.id group by t.aliased_tag_id;
	SQL

implied_tags: tag_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_tags.tag_search_json (tag_id, object) select it.tag_id, jsonb_build_object('implied_tag_ids', jsonb_agg(it.implied_tag_id), 'implied_tags', jsonb_agg(t.name)) from tags_implied_tags it inner join tags t on t.id=it.implied_tag_id group by it.tag_id;
	SQL

implied_by_tags: tag_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_tags.tag_search_json (tag_id, object) select it.implied_tag_id, jsonb_build_object('implied_by_tags', jsonb_agg(t.name)) from tags_implied_tags it inner join tags t on t.id=it.tag_id group by it.implied_tag_id;
	SQL

tag_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_tags cascade;
		create schema temp_tags;
		create unlogged table temp_tags.tag_search_json (tag_id bigint not null, object jsonb not null);
		create or replace aggregate temp_tags.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
