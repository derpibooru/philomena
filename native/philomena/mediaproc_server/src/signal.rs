use tokio::signal::unix::{SignalKind, signal};

pub fn install_handlers() {
    let mut sigterm = signal(SignalKind::terminate()).unwrap();
    let mut sigint = signal(SignalKind::interrupt()).unwrap();

    tokio::spawn(async move {
        tokio::select! {
            _ = sigterm.recv() => tracing::debug!("Received SIGTERM"),
            _ = sigint.recv() => tracing::debug!("Received SIGINT"),
        };

        std::process::exit(1);
    });
}
