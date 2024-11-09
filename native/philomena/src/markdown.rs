use crate::{camo, domains};
use comrak::Options;
use std::collections::HashMap;

fn common_options() -> Options {
    let mut options = Options::default();
    options.extension.autolink = true;
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.superscript = true;
    options.extension.strikethrough = true;
    options.extension.philomena = true;
    options.parse.smart = true;
    options.render.hardbreaks = true;
    options.render.github_pre_lang = true;

    options.extension.camoifier = Some(|s| camo::image_url_careful(&s));
    options.extension.philomena_domains = domains::get();

    options
}

pub fn to_html(input: &str, reps: HashMap<String, String>) -> String {
    let mut options = common_options();
    options.render.escape = true;
    options.extension.philomena_replacements = Some(reps);

    comrak::markdown_to_html(input, &options)
}

pub fn to_html_unsafe(input: &str, reps: HashMap<String, String>) -> String {
    let mut options = common_options();
    options.render.unsafe_ = true;
    options.extension.philomena_replacements = Some(reps);

    comrak::markdown_to_html(input, &options)
}
