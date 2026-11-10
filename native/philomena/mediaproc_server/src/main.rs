use std::net::SocketAddr;

use clap::Parser;
use futures::{Future, StreamExt, future};
use mediaproc::{CommandReply, ExecuteCommandError, FileMap, MediaProcessor};
use tarpc::context;
use tarpc::server::Channel;

mod command_server;
mod signal;

#[derive(Parser, Debug)]
#[command(version, about = "RPC Media Processor Server", long_about = None)]
struct Arguments {
    /// Socket address to bind to, like 127.0.0.1:1500
    server_addr: SocketAddr,
}

#[derive(Clone)]
struct MediaProcessorServer;

impl MediaProcessor for MediaProcessorServer {
    async fn execute_command(
        self,
        _: context::Context,
        program: String,
        arguments: Vec<String>,
        file_map: FileMap,
    ) -> Result<(CommandReply, FileMap), ExecuteCommandError> {
        command_server::execute_command(program, arguments, file_map).await
    }

    async fn get_mime(
        self,
        _: context::Context,
        content: Vec<u8>,
    ) -> Result<String, ExecuteCommandError> {
        command_server::get_mime(content).await
    }
}

fn main() {
    env_logger::init();

    let args = Arguments::parse();

    serve(&args);
}

async fn spawn(fut: impl Future<Output = ()> + Send + 'static) {
    tokio::spawn(fut);
}

#[tokio::main]
async fn serve(args: &Arguments) {
    signal::install_handlers();

    let codec = tarpc::tokio_serde::formats::Bincode::default;
    let mut listener = tarpc::serde_transport::tcp::listen(args.server_addr, codec)
        .await
        .unwrap();

    listener.config_mut().max_frame_length(usize::MAX);
    listener
        // Ignore accept errors.
        .filter_map(|r| future::ready(r.ok()))
        .map(tarpc::server::BaseChannel::with_defaults)
        .map(|channel| {
            tokio::spawn(
                channel
                    .execute(MediaProcessorServer.serve())
                    .for_each(spawn),
            );
        })
        .collect()
        .await
}
