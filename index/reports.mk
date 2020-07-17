DATABASE ?= philomena
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=reports.jsonl --output=http://localhost:9200/ --output-index=reports --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc)"

dump_jsonl: metadata image_ids comment_image_ids
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_reports.jsonb_object_agg(object) from temp_reports.report_search_json group by report_id) to stdout;' > reports.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_reports cascade;'
	sed -i reports.jsonl -e 's/\\\\/\\/g'

metadata: report_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_reports.report_search_json (report_id, object) select r.id, jsonb_build_object(
			'id', r.id,
			'created_at', r.created_at,
			'ip', r.ip,
			'state', r.state,
			'user', lower(u.name),
			'user_id', r.user_id,
			'admin', lower(a.name),
			'admin_id', r.admin_id,
			'reportable_type', r.reportable_type,
			'reportable_id', r.reportable_id,
			'fingerprint', r.fingerprint,
			'open', r.open,
			'reason', r.reason
		) from reports r left join users u on r.user_id=u.id left join users a on r.admin_id=a.id;
	SQL

image_ids: report_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_reports.report_search_json (report_id, object) select r.id, jsonb_build_object('image_id', r.reportable_id) from reports r where r.reportable_type = 'Image';
	SQL

comment_image_ids: report_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_reports.report_search_json (report_id, object) select r.id, jsonb_build_object('image_id', c.image_id) from reports r inner join comments c on c.id = r.reportable_id where r.reportable_type = 'Comment';
	SQL

report_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_reports cascade;
		create schema temp_reports;
		create unlogged table temp_reports.report_search_json (report_id bigint not null, object jsonb not null);
		create or replace aggregate temp_reports.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
