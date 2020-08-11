# Philomena
![Philomena](/assets/static/images/phoenix.svg)

![Philomena Build](https://github.com/booru/philomena/workflows/Philomena%20Build/badge.svg)

## Demo System
A demo install of this software can be found at <https://boorudemo.basisbit.de>. Bear in mind that any data uploaded to this demo/test system will be lost after a couple of hours.

## Getting started
On systems with `docker` and `docker-compose` installed, the process should be as simple as:

```
cp .env.example .env
docker-compose build
docker-compose up
```

If you use `podman` and `podman-compose` instead, the process for constructing a rootless container is nearly identical:

```
cp .env.example .env
podman-compose build
podman-compose up
```

Once the application has started, navigate to http://localhost:8080 and login with admin@example.com / DemoBooruPassword

## System Requirements

Minimal requirements are 2 CPU threads and 4GB of RAM. A 5€/$ per month VPS will work well as development/testing machine.

Recommended for production with many active users would be 6+ dedicated CPU cores, 32+ GB of RAM, dedicated unlimited 1Gb/s network port or better and the system should use only SSD/NVMe as data storage to handle the required IOPS load.

If that is not enough capacity for your use case, consider using a couple of servers as "CDN" which only host the image files. We also suggest using Cloudflare or similar in front of the image board and configuring a cloudflare page rule to enfore caching of the image files.

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
```
cd ~
mkdir booru
cd booru
git clone https://github.com/booru/philomena
cd philomena
sed -i 's/DemoBooruPassword/YourNewDesiredSecretPassword/g' ~/booru/philomena/priv/repo/seeds.json
sed -i 's/admin@example.com/yourAdmin@email.tld/g' ~/booru/philomena/priv/repo/seeds.json
sed -i 's/Administrator/YourAdminAccountName/g' ~/booru/philomena/priv/repo/seeds.json
sed -i 's/MIX_ENV=dev/MIX_ENV=prod/g' ~/booru/philomena/docker-compose.yml
cp .env.example .env
docker-compose build
```
For production set DEV_MODE=false, APP_ENV=prod und MIX_ENV=prod in the file `.env`. For development, set DEV_MODE=true, APP_ENV=dev, and MIX_ENV=dev in the file `.env`. If you don't want a new db at every start in dev mode, set MIX_ENV=prod.
If this is your first start on this machine or you reset the docker virtual disks, follow these steps to create a new database. Otherwise, just execute `docker-compose up` to start the application.
To start the containers as daemon, run `docker-compose up -d`. To run it as process with log output to console, run `docker-compose up`.

Uncomment the entrypoint line in `docker-compose.yml`. Run `docker-compose up`. In another shell, run `docker-compose exec app bash`. Then:
```
# PGPASSWORD=$POSTGRES_PASSWORD dropdb -h $POSTGRES_HOST -U $POSTGRES_USER $POSTGRES_DB
PGPASSWORD=$POSTGRES_PASSWORD createdb -h $POSTGRES_HOST -U $POSTGRES_USER $POSTGRES_DB
mix ecto.setup
mix reindex_all
mix ecto.migrate
exit
docker-compose down
```
Comment the entrypoint line in `docker-compose.yml` (add the # again). Then start the app by running `docker-compose up`.


## Customize
To customize your booru, find and replace all occurences of the following words with your desired content
- `YourBooruName`
- `YourBooruDescription` (sample: `Samplebooru is a linear imagebooru which lets you share, find and discover new art and media surrounding samples.`
- `SomeRandomSampleSecret1234`
- Rule names that are selectable when reporting violations can be adjusted in `lib/philomena_web/views/report_view.ex`
- In `config/config.exs` `tumblr_api_key`
- Predefined forum sections can be changed in `priv/repo/seeds.json` in the forums section
- Set a custom secret_key_base as `SECRET_KEY_BASE` system environment for the app container in the `.env` file. To create one such secret, run `mix phx.gen.secret` within the app container.

### image_url_root
The baseUrl for image requests can be changed using the `image_url_root` variable in `config/config.exs`. This url is used for rendering images onto the html templates and changing it can be used to cache request with a cdn. The Proxy has to redirect to the `/img` endpoint of philomena. (see `lib/philomena_web/views/image_view.ex:85`). It is appended with either `view` or `download` depending on the context, as well as the date of upload and the image filename. Thumbnails will use the image-id as well as the thumbnail size (see `lib/philomena_web/views/image_view.ex:47`)

## gdpr-cron container
The docker container located in ```docker/gdpr``` contains a cronjob scheduler used to comply with the
european _general data protection regulation_. The list of scripts can be extended as needed

### Adding a script to the container
Adding a new script to the container can be easily archived by creating the script file, adding it to the crontab.txt,
using the known [crontab](http://manpages.ubuntu.com/manpages/cosmic/man5/crontab.5.html) syntax and making sure that
the script is copied to the correct path in the dockerfile

#### anonymize-ips.sh
This script replaces the uploaders IP of an image with ```0.0.0.0```
14 days after uploading. The time can be configured using the ```MAX_AGE``` environment variable. The values is an
[postgresql intervals](https://www.postgresql.org/docs/12/datatype-datetime.html#DATATYPE-INTERVAL-INPUT)

The script uses [postgres-client environment variables](https://www.postgresql.org/docs/9.3/libpq-envars.html) to configure the database connection
