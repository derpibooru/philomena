use jemallocator::Jemalloc;

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
fn markdown_to_html(input: String) -> String {
    markdown::to_html(input)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html_unsafe(input: String) -> String {
    markdown::to_html_unsafe(input)
}

// Camo NIF wrappers.

#[rustler::nif]
fn camo_image_url(input: String) -> String {
    camo::image_url(input).unwrap_or_else(|| String::from(""))
}
