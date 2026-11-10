use std::path::Path;

use mediaproc::{CommandReply, ExecuteCommandError, FileMap, PERMITTED_PROGRAMS};
use tokio::process::Command;

fn validate_name(name: &str) -> Result<(), ExecuteCommandError> {
    if name == "." || name.contains("..") || name.contains('/') || name.contains('\\') {
        return Err(ExecuteCommandError::InvalidFileMapName);
    }

    Ok(())
}

pub async fn execute_command(
    program: String,
    arguments: Vec<String>,
    file_map: FileMap,
) -> Result<(CommandReply, FileMap), ExecuteCommandError> {
    use std::fs::write;

    // Check program name.
    if !PERMITTED_PROGRAMS.contains(&program.as_ref()) {
        return Err(ExecuteCommandError::UnpermittedProgram(program));
    }

    // Create a new temporary directory which we will work in.
    let dir = tempfile::tempdir().map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

    // Verify and write out all files.
    for (name, contents) in &file_map {
        validate_name(name)?;
        write(dir.path().join(name), contents)
            .map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;
    }

    // Run the command.
    let output = Command::new(program)
        .args(arguments)
        .current_dir(dir.path())
        .output()
        .await
        .map_err(|_| ExecuteCommandError::ExecutionError)?;

    let file_map = changed_files(dir.path(), file_map)?;

    let reply = CommandReply {
        status: output.status.code().unwrap_or(255) as u8,
        stdout: output.stdout,
        stderr: output.stderr,
    };

    Ok((reply, file_map))
}

/// Reads back the files in `dir` whose contents differ from `inputs`, so the
/// client never rewrites inputs that other jobs may be reading.
fn changed_files(dir: &Path, inputs: FileMap) -> Result<FileMap, ExecuteCommandError> {
    inputs
        .into_iter()
        .filter_map(|(name, original)| match std::fs::read(dir.join(&name)) {
            Ok(contents) if contents == original => None,
            Ok(contents) => Some(Ok((name, contents))),
            Err(_) => Some(Err(ExecuteCommandError::RemoteFilesystemError)),
        })
        .collect()
}

pub async fn get_mime(content: Vec<u8>) -> Result<String, ExecuteCommandError> {
    use std::fs::write;

    // Write the contents to a file in a new temporary directory.
    let dir = tempfile::tempdir().map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;
    let path = dir.path().join("file");
    write(&path, content).map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

    let output = Command::new("file")
        .arg("-b")
        .arg("--mime-type")
        .arg(&path)
        .output()
        .await
        .map_err(|_| ExecuteCommandError::ExecutionError)?;

    if !output.status.success() {
        return Err(ExecuteCommandError::ExecutionError);
    }

    match String::from_utf8(output.stdout) {
        Ok(mime) => Ok(mime.trim().to_string()),
        Err(_) => Err(ExecuteCommandError::UnknownError),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn changed_files_returns_only_files_the_command_wrote() {
        let dir = tempfile::tempdir().unwrap();
        let inputs = FileMap::from([
            ("0.icc".to_string(), b"profile".to_vec()),
            ("1.png".to_string(), Vec::new()),
        ]);

        std::fs::write(dir.path().join("0.icc"), b"profile").unwrap();
        std::fs::write(dir.path().join("1.png"), b"output").unwrap();

        let changed = changed_files(dir.path(), inputs).unwrap();

        assert_eq!(
            changed,
            FileMap::from([("1.png".to_string(), b"output".to_vec())])
        );
    }
}
