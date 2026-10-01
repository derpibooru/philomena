# Philomena

![Philomena](/assets/static/images/phoenix.svg)

## Getting Started

Make sure you have [Docker](https://docs.docker.com/engine/install/) and [Docker Compose plugin](https://docs.docker.com/compose/install/#scenario-two-install-the-docker-compose-plugin) installed.

You can open this repo via a [devcontainer](https://containers.dev/) in VSCode, JetBrains, GitHub Codespaces or any other [supported IDE](https://containers.dev/supporting). This setup is the recommended way to develop and this way it's guaranteed everyone uses the same dev configs and dependencies.

If you can't/don't want to use devcontainers, then go through the [`docker/app/Dockerfile`](docker/app/Dockerfile) to see what dependencies/configurations you need to set up on your host machine.

<sub>Note that there are some additional [Prerequisites for Remote SSH Development](#prerequisites-for-remote-ssh-development).</sub>

## Dev Stack

Use the following commands to bring up or shut down the dev stack.

```bash
philomena up
philomena down
```

Once the application has started, navigate to http://localhost:8080 and log in with

| Credential | Value               |
| ---------- | ------------------- |
| Email      | `admin@example.com` |
| Password   | `philomena123`      |

> [!TIP]
> See the source code of `scripts/philomena.sh` for details on the additional parameters and other subcommands.

## Devcontainer Specifics

The devcontainer is configured with the `docker-compose.yml`. The IDE attaches to the `app` service of the stack. You can use `docker compose` to manage the stack but be careful not to shutdown the `app` service. Use `philomena` commands instead that make sure the `app` service is always running.

### Prerequisites for Remote SSH Development

If you are developing on a remote SSH host that runs a devcontainer, then make sure to configure port forwarding like this:

| Port     | Forwarded Address |
| -------- | ----------------- |
| `web:80` | `localhost:80`    |
| `5173`   | `localhost:5173`  |

Yes, use the `host:port` notation for `web:80`. It's because the `web` service runs in a separate container.

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
