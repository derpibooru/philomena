use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

pub mod client;

#[tarpc::service]
pub trait MediaProcessor {
    /// Executes a command on the media processor server, returning the files
    /// in `file_map` whose contents the command changed.
    async fn execute_command(
        program: String,
        arguments: Vec<String>,
        file_map: FileMap,
    ) -> Result<(CommandReply, FileMap), ExecuteCommandError>;

    /// Gets the MIME type of the given file contents, as reported by file(1).
    async fn get_mime(content: Vec<u8>) -> Result<String, ExecuteCommandError>;
}

/// Errors which can occur during command execution.
#[derive(Debug, Deserialize, Serialize)]
pub enum ExecuteCommandError {
    /// Requested program was not allowed to be executed.
    UnpermittedProgram(String),
    /// Failed to launch program.
    ExecutionError,
    /// File map name character was not allowed ('..', '/', '\\').
    InvalidFileMapName,
    /// Generic filesystem error.
    RemoteFilesystemError,
    /// Generic filesystem error.
    LocalFilesystemError,
    /// Unknown error.
    UnknownError,
}

/// Enumeration of permitted program names.
pub static PERMITTED_PROGRAMS: LazyLock<HashSet<&'static str>> = LazyLock::new(|| {
    vec![
        "ffprobe",
        "ffmpeg",
        "gifsicle",
        "image-intensities",
        "jpegtran",
        "magick",
        "mediastat",
        "mediathumb",
        "optipng",
        "safe-rsvg-convert",
        "svgstat",
    ]
    .into_iter()
    .collect()
});

/// Mapping between file name and file contents.
pub type FileMap = HashMap<String, Vec<u8>>;

/// Output reply after command execution has finished.
#[derive(Debug, Deserialize, Serialize)]
pub struct CommandReply {
    pub status: u8,
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
}
