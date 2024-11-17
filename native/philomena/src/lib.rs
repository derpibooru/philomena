use jemallocator::Jemalloc;
use rustler::{Atom, Binary, Env, Term};
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
    "Elixir.Philomena.Native",
    [
        markdown_to_html, markdown_to_html_unsafe, markdown_to_cm,
        markdown_has_subscript, camo_image_url, zip_open_writer,
        zip_start_file, zip_write, zip_finish
    ],
    load = load
}

// Setup.

fn load(env: Env, arg: Term) -> bool {
    zip::load(env, arg)
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

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_cm(input: &str) -> String {
    markdown::to_cm(input)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_has_subscript(input: &str) -> bool {
    markdown::has_subscript(input)
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
