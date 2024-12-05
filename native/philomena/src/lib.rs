use jemallocator::Jemalloc;
use rustler::{Atom, Binary};
use std::collections::HashMap;

mod camo;
mod domains;
mod markdown;
#[cfg(test)]
mod tests;
mod zip;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;

rustler::init! {
    "Elixir.Philomena.Native"
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

// Zip NIF wrappers.

#[rustler::nif]
fn zip_open_writer(path: &str) -> Result<zip::WriterResourceArc, Atom> {
    zip::open_writer(path)
}

#[rustler::nif]
fn zip_start_file(writer: zip::WriterResourceArc, name: &str) -> Atom {
    zip::start_file(writer, name)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn zip_write(writer: zip::WriterResourceArc, data: Binary) -> Atom {
    zip::write(writer, data.as_slice())
}

#[rustler::nif(schedule = "DirtyCpu")]
fn zip_finish(writer: zip::WriterResourceArc) -> Atom {
    zip::finish(writer)
}
