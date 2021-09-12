use comrak::{markdown_to_html, ComrakOptions};
use jemallocator::Jemalloc;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;

rustler::init! {
    "Elixir.Philomena.Markdown",
    [to_html, to_html_unsafe]
}

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
    options
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(input: String) -> String {
    let mut options = common_options();
    options.render.escape = true;

    markdown_to_html(&input, &options)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html_unsafe(input: String) -> String {
    let mut options = common_options();
    options.render.unsafe_ = true;

    markdown_to_html(&input, &options)
}
