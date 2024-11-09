use jemallocator::Jemalloc;
use std::collections::HashMap;

mod camo;
mod domains;
mod markdown;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;

rustler::init! {
    "Elixir.Philomena.Native",
    [markdown_to_html, markdown_to_html_unsafe, camo_image_url]
}

// Markdown NIF wrappers.

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html(input: &str, reps: HashMap<String, String>) -> String {
    markdown::to_html(input, reps)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html_unsafe(input: &str, reps: HashMap<String, String>) -> String {
    markdown::to_html_unsafe(input, reps)
}

// Camo NIF wrappers.

#[rustler::nif]
fn camo_image_url(input: &str) -> String {
    camo::image_url_careful(input)
}
