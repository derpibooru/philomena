use rustler::{Atom, Env, OwnedEnv, Term};
use std::future::Future;
use std::marker::Send;
use std::sync::LazyLock;
use tokio::runtime::Runtime;

static RUNTIME: LazyLock<Runtime> = LazyLock::new(|| Runtime::new().unwrap());

pub fn call_async<F, T, W>(caller_env: Env, fut: F, w: W) -> Atom
where
    F: Future<Output = T> + Send + 'static,
    W: for<'a> FnOnce(Env<'a>, T) -> Term<'a>,
    W: Send + 'static,
{
    let pid = caller_env.pid();

    RUNTIME.spawn(async move {
        let output = fut.await;
        let owned_env = OwnedEnv::new();
        owned_env.run(move |env| {
            let _ = env.send(&pid, w(env, output));
        });
    });

    rustler::types::atom::ok()
}
