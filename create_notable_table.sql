CREATE TABLE IF NOT EXISTS notable_names (
	name		varchar PRIMARY KEY,
	source	text NOT NULL,

	created_at timestamp DEFAULT current_timestamp
);

DROP TRIGGER IF EXISTS notable_name_insert_trigger on public.notable_names;

CREATE OR REPLACE FUNCTION notable_name_processing(name text)
RETURNS text AS '
BEGIN
	name := regexp_replace(name,''[|/\.,?><:~!@#$%^&*_=+\011\042\047\050\051\073\133\135\140\173\175-]+'','''',''g'');
	name := regexp_replace(name,''\s+'','''',''g'');
	name := LOWER(name);
	RETURN name;
END' LANGUAGE 'plpgsql';	

CREATE OR REPLACE FUNCTION notable_name_query(query_name text)
RETURNS TABLE (name varchar, source text, created_at timestamp) AS '
BEGIN
	query_name := notable_name_processing(query_name);
	RETURN QUERY SELECT * FROM notable_names WHERE notable_names.name=query_name;
END' LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION notable_name_insert_processing()
RETURNS trigger AS '
BEGIN
	NEW.name := notable_name_processing(NEW.name);
	RETURN NEW;
END' LANGUAGE 'plpgsql';

CREATE TRIGGER notable_name_insert_trigger
BEFORE INSERT ON notable_names
FOR EACH ROW
EXECUTE PROCEDURE notable_name_insert_processing();
