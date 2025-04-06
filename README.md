# Philomena

![Philomena](/assets/static/images/phoenix.svg)

## Getting Started

Make sure you have [Docker](https://docs.docker.com/engine/install/) and [Docker Compose plugin](https://docs.docker.com/compose/install/#scenario-two-install-the-docker-compose-plugin) installed.

Add the directory `scripts/path` to your `PATH` to get the `philomena` dev CLI globally available in your terminal. For example you can add the following to your shell's `.*rc` file, but adjust the path to philomena repo accordingly.

```bash
export PATH="$PATH:$HOME/dev/philomena/scripts/path"
```

Use the following commands to bring up or shut down a dev server.

```bash
philomena up
philomena down
```

Once the application has started, navigate to http://localhost:8080 and login with

| Credential | Value               |
| ---------- | ------------------- |
| Email      | `admin@example.com` |
| Password   | `philomena123`      |

> [!TIP]
> See the source code of `scripts/philomena.sh` for details on the additional parameters and other subcommands.

## Pre-commit hook

Run the following command to configure the git pre-commit hook that will auto-format the code and run lightweight checks on each commit.

```bash
philomena init
```

## IDE Setup

If you are using VSCode, you are encouraged to install the recommended extensions that VSCode should automatically suggest to you based on `.vscode/extensions.json` file in this repo.

## Updates

We regularly bump our dev tool versions, so if you want to stay in sync, make sure to rerun `philomena init` from time to time to get the latest updates.

That command downloads and stores some dev tools under the `.tools` directory. If you don't keep in sync with this, our CI will catch any errors anyway, so don't worry.

## Troubleshooting

If you are running Docker on Windows and the application crashes immediately upon startup, please ensure that `autocrlf` is set to `false` in your Git config, and then re-clone the repository. Additionally, it is recommended that you allocate at least 4GB of RAM to your Docker VM.

If you run into an OpenSearch bootstrap error, you may need to increase your `max_map_count` on the host as follows:

```
sudo sysctl -w vm.max_map_count=262144
```

If you have SELinux enforcing (Fedora, Arch, others; manifests as a `Could not find a Mix.Project` error), you should run the following in the application directory on the host before proceeding:

```
chcon -Rt svirt_sandbox_file_t .
```

This allows Docker or Podman to bind mount the application directory into the containers.

If you are using a platform which uses cgroups v2 by default (Fedora 31+), use `podman` and `podman-compose`.

## Deployment

You need a key installed on the server you target, and the git remote installed in your ssh configuration.

    git remote add production philomena@<serverip>:philomena/

The general syntax is:

    git push production master

And if everything goes wrong:

    git reset HEAD^ --hard
    git push -f production master

(to be repeated until it works again)
