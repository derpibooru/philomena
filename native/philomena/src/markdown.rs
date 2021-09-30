use comrak::ComrakOptions;
use crate::camo;
use rustler::{MapIterator, Term};
use std::collections::HashMap;
use std::env;

fn common_options() -> ComrakOptions {
    let mut options = ComrakOptions::default();
    options.extension.autolink = true;
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.superscript = true;
    options.extension.strikethrough = true;
    options.extension.philomena = true;
    options.parse.smart = true;
    options.render.hardbreaks = true;
    options.render.github_pre_lang = true;

    options.extension.camoifier = Some(|s| camo::image_url(s).unwrap_or_else(|| String::from("")));

    if let Ok(domains) = env::var("SITE_DOMAINS") {
        options.extension.philomena_domains = Some(domains.split(',').map(|s| s.to_string()).collect::<Vec<String>>());
    }

    options
}

fn map_to_hashmap(map: Term) -> Option<HashMap<String, String>> {
    Some(MapIterator::new(map)?.map(|(key, value)| {
        let key: String = key.decode().unwrap_or_else(|_| String::from(""));
        let value: String = value.decode().unwrap_or_else(|_| String::from(""));

        (key, value)
    }).collect())
}

pub fn to_html(input: String, reps: Term) -> String {
    let mut options = common_options();
    options.render.escape = true;

    options.extension.philomena_replacements = map_to_hashmap(reps);

    comrak::markdown_to_html(&input, &options)
}

pub fn to_html_unsafe(input: String, reps: Term) -> String {
    let mut options = common_options();
    options.render.unsafe_ = true;

    options.extension.philomena_replacements = map_to_hashmap(reps);

    comrak::markdown_to_html(&input, &options)
}
