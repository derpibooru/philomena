use crate::{camo, markdown, markdown_diff};
use rustler::{Atom, Binary, Env};
use std::collections::HashMap;

mod asyncnif;
mod remote;
mod zip;

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

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_diff_to_html(old: &str, new: &str) -> String {
    markdown_diff::to_html(old, new)
}

// Camo NIF wrappers.

#[rustler::nif]
fn camo_image_url(input: &str) -> String {
    camo::image_url(input)
}

// Remote NIF wrappers.

#[rustler::nif]
fn async_process_command(
    env: Env,
    server_addr: String,
    program: String,
    arguments: Vec<String>,
) -> Atom {
    let fut = remote::process_command(server_addr, program, arguments);
    asyncnif::call_async(env, fut, remote::with_env)
}

#[rustler::nif]
fn async_get_mime(env: Env, server_addr: String, path: String) -> Atom {
    let fut = remote::get_mime(server_addr, path);
    asyncnif::call_async(env, fut, remote::mime_with_env)
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
