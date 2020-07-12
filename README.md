# Philomena
![Philomena](/assets/static/images/phoenix.svg)

## Getting started
On systems with `docker` and `docker-compose` installed, the process should be as simple as:

```
docker-compose build
docker-compose up
```

If you use `podman` and `podman-compose` instead, the process for constructing a rootless container is nearly identical:

```
podman-compose build
podman-compose up
```

Once the application has started, navigate to http://localhost:8080 and login with admin@example.com / trixieisbestpony

## Troubleshooting

If you are running Docker on Windows and the application crashes immediately upon startup, please ensure that `autocrlf` is set to `false` in your Git config, and then re-clone the repository. Additionally, it is recommended that you allocate at least 4GB of RAM to your Docker VM.

If you run into an Elasticsearch bootstrap error, you may need to increase your `max_map_count` on the host as follows:
```
sudo sysctl -w vm.max_map_count=262144
```

If you have SELinux enforcing, you should run the following in the application directory on the host before proceeding:
```
chcon -Rt svirt_sandbox_file_t .
```
This allows Docker or Podman to bind mount the application directory into the containers.

The postgres DB can be deleted like this:
```
docker container ls
docker container rm philomena_postgres_1
docker volume ls
docker volume rm philomena_postgres_data
```

To manually start the app container and run commands from `docker/app/run-development` or `docker/app/run-prod`, uncomment the entrypoint line in `docker-compose.yml`, then run `docker-compose up`. In another shell, run `docker-compose exec app bash` and you should be good to go. As next steps, you'll usually want to manually execute the commands from the above mentioned run scripts and look at the console output to see what the problem is. From this container, you can also connect to the postgresql database using `psql -h postgres -U postgres`.

## Deployment
You need a key installed on the server you target, and the git remote installed in your ssh configuration.

    git remote add production philomena@<serverip>:philomena/

The general syntax is:

    git push production master

And if everything goes wrong:

    git reset HEAD^ --hard
    git push -f production master

(to be repeated until it works again)

## Customize
To customize your booru, find and replace all occurences of the following words with your desired content
- `YourBooruName`
- `YourBooruDescription` (sample: `Samplebooru is a linear imagebooru which lets you share, find and discover new art and media surrounding samples.`
