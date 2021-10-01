use jemallocator::Jemalloc;
use rustler::Term;

mod camo;
mod markdown;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;

rustler::init! {
    "Elixir.Philomena.Native",
    [markdown_to_html, markdown_to_html_unsafe, camo_image_url]
}

// Markdown NIF wrappers.

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html(input: String, reps: Term) -> String {
    markdown::to_html(input, reps)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html_unsafe(input: String, reps: Term) -> String {
    markdown::to_html_unsafe(input, reps)
}

// Camo NIF wrappers.

#[rustler::nif]
fn camo_image_url(input: String) -> String {
    camo::image_url(input).unwrap_or_else(|| String::from(""))
}
