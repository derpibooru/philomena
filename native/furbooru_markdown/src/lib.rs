use comrak::{markdown_to_html, ComrakOptions};
use lazy_static::lazy_static;
use regex::{Captures, Regex};
use rustler::Term;

mod atoms {
    rustler::atoms! {
        ok,
    }
}

rustler::init! {
    "Elixir.Philomena.Markdown",
    [to_html, to_html_unsafe]
}

const IMAGE_MENTION_REGEX: &'static str = r#"&gt;&gt;([0-9]+)([|t|s|p]?)"#;

lazy_static! {
    static ref IMAGE_MENTION_REPLACE: Regex = Regex::new(IMAGE_MENTION_REGEX).unwrap();
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(input: String) -> String {
    let _ = pretty_env_logger::try_init();
    let mut text: String = input;

    if text.contains(">>") {
        text = text.replace(">>", "&gt;&gt;");
    }

    let mut options = ComrakOptions::default();
    options.extension.autolink = true;
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.superscript = true;
    options.extension.subscript = true;
    options.extension.spoiler = true;
    options.extension.strikethrough = true;
    // options.extension.furbooru = true;
    options.parse.smart = true;
    options.render.hardbreaks = true;
    options.render.github_pre_lang = true;
    options.render.escape = true;
    let mut result = markdown_to_html(&text, &options);

    result = match IMAGE_MENTION_REPLACE.captures(&result) {
        None => result,
        Some(fields) => {
            match fields.get(2).unwrap().as_str() {
                "t" => result, // TODO(Xe): thumbnail rendering
                "s" => result, // TODO(Xe): small preview rendering
                "p" => result, // TODO(Xe): large preview rendering
                "" => String::from(
                    IMAGE_MENTION_REPLACE.replace_all(&result, |caps: &Captures| {
                        format!(r#"<a href="/images/{0}">&gt;&gt;{0}</a>"#, &caps[1])
                    }),
                ),
                _ => result,
            }
        }
    };

    result
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html_unsafe(input: String) -> String {
    let mut text: String = input;

    if text.contains(">>") {
        text = text.replace(">>", "&gt;&gt;");
    }

    let mut options = ComrakOptions::default();
    options.extension.autolink = true;
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.superscript = true;
    options.extension.subscript = true;
    options.extension.spoiler = true;
    options.extension.strikethrough = true;
    options.extension.front_matter_delimiter = Some("---".to_owned());
    // options.extension.furbooru = true;
    options.parse.smart = true;
    options.render.hardbreaks = true;
    options.render.github_pre_lang = true;
    options.render.unsafe_ = true;

    let result = markdown_to_html(&text, &options);

    result
}
