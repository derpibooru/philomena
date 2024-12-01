use std::fs::{File, OpenOptions};
use std::io::Write;
use std::sync::Mutex;

use rustler::{Atom, Env, ResourceArc, Term};
use zip::{write::SimpleFileOptions, CompressionMethod, ZipWriter};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub struct WriterResource {
    inner: Mutex<Option<ZipWriter<File>>>,
}

pub type WriterResourceArc = ResourceArc<WriterResource>;

// TODO: rustler must fix the resource macro to provide a top-level impl definiton
#[allow(non_local_definitions)]
pub fn load(env: Env, _: Term) -> bool {
    rustler::resource!(WriterResource, env);
    true
}

fn with_writer<F, T>(writer: WriterResourceArc, f: F) -> Atom
where
    F: FnOnce(&mut Option<ZipWriter<File>>) -> Option<T>,
{
    let mut guard = match (*writer).inner.lock() {
        Ok(g) => g,
        Err(_) => return atoms::error(),
    };

    match f(&mut guard) {
        Some(_) => atoms::ok(),
        None => atoms::error(),
    }
}

pub fn open_writer(path: &str) -> Result<WriterResourceArc, Atom> {
    match OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(path)
    {
        Ok(file) => Ok(ResourceArc::new(WriterResource {
            inner: Mutex::new(Some(ZipWriter::new(file))),
        })),
        Err(_) => Err(atoms::error()),
    }
}

pub fn start_file(writer: WriterResourceArc, name: &str) -> Atom {
    let options = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);

    with_writer(writer, move |writer| {
        writer.as_mut()?.start_file(name, options).ok()
    })
}

pub fn write(writer: WriterResourceArc, data: &[u8]) -> Atom {
    with_writer(writer, move |writer| writer.as_mut()?.write(data).ok())
}

pub fn finish(writer: WriterResourceArc) -> Atom {
    with_writer(writer, move |writer| writer.take().map(|w| w.finish().ok()))
}
