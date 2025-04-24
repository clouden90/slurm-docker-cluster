# Slurm Docker Cluster with simple rocoto workflow example

## How to run simple example

Clone the repo:
```bash
git clone -b fun https://github.com/clouden90/slurm-docker-cluster.git
```

## Download the example data and create empty folders
```bash
cd slurm-docker-cluster
mkdir -p scratch/mom6/nwa12/forecast_input_data
mkdir -p scratch/seasonal-workflow/logs
mkdir -p scratch/nwa12/setup
wget -r -np -nH --cut-dirs=4 -A ".nc" ftp://ftp.gfdl.noaa.gov/pub/Yi-cheng.Teng/nwa12/setup/grid/ -P scratch/nwa12/setup/
mkdir -p scratch/spear
wget ftp://ftp.gfdl.noaa.gov/pub/Yi-cheng.Teng/spear/atmos.static.nc -P scratch/spear/ 
wget ftp://ftp.gfdl.noaa.gov/pub/Yi-cheng.Teng/spear_data_backup.tar.gz
tar -zxvf spear_data_backup.tar.gz
```

## build Slurm Docker Cluster Image
```bash
docker compose build
```

## Starting the Cluster
```bash
docker compose up -d
```

## Accessing the Cluster
```bash
docker exec -it slurmctld bash
```

## Try simple rocoto workflow
```bash
cd /scratch/seasonal-workflow/flow
conda activate uwtools
uw rocoto realize --config-file retrospective_workflow_example.yaml --output-file retrospective_workflow_example.xml
rocotorun -d retrospective_workflow_example.db -w retrospective_workflow_example.xml
rocotostat -d retrospective_workflow_Example.db -w retrospective_workflow_example.xml
```
Repeat rocotorun and rocotostat and you should see the following:
```bash
(uwtools) [root@slurmctld flow]# rocotostat -d retrospective_workflow_Example.db -w retrospective_workflow_example.xml
       CYCLE                    TASK                       JOBID               STATE         EXIT STATUS     TRIES      DURATION
================================================================================================================================
199404010000       write_spear_atmos                           7           SUCCEEDED                   0         1           6.0
================================================================================================================================
199504010000       write_spear_atmos                           8           SUCCEEDED                   0         1           6.0
```



**Slurm Docker Cluster** is a multi-container Slurm cluster designed for rapid
deployment using Docker Compose. This repository simplifies the process of
setting up a robust Slurm environment for development, testing, or lightweight
usage.

## 🏁 Getting Started

To get up and running with Slurm in Docker, make sure you have the following tools installed:

- **[Docker](https://docs.docker.com/get-docker/)**
- **[Docker Compose](https://docs.docker.com/compose/install/)**

Clone the repository:

```bash
git clone https://github.com/giovtorres/slurm-docker-cluster.git
cd slurm-docker-cluster
```

## 📦 Containers and Volumes

This setup consists of the following containers:

- **mysql**: Stores job and cluster data.
- **slurmdbd**: Manages the Slurm database.
- **slurmctld**: The Slurm controller responsible for job and resource management.
- **c1, c2**: Compute nodes (running `slurmd`).

### Persistent Volumes:

- `etc_munge`: Mounted to `/etc/munge`
- `etc_slurm`: Mounted to `/etc/slurm`
- `slurm_jobdir`: Mounted to `/data`
- `var_lib_mysql`: Mounted to `/var/lib/mysql`
- `var_log_slurm`: Mounted to `/var/log/slurm`

## 🛠️  Building the Docker Image

The version of the Slurm project and the Docker build process can be simplified
by using a `.env` file, which will be automatically picked up by Docker Compose.

Update the `SLURM_TAG` and `IMAGE_TAG` found in the `.env` file and build
the image:

```bash
docker compose build
```

Alternatively, you can build the Slurm Docker image locally by specifying the
[SLURM_TAG](https://github.com/SchedMD/slurm/tags) as a build argument and
tagging the container with a version ***(IMAGE_TAG)***:

```bash
docker build --build-arg SLURM_TAG="slurm-21-08-6-1" -t slurm-docker-cluster:21.08.6 .
```

## 🚀 Starting the Cluster

Once the image is built, deploy the cluster with the default version of slurm
using Docker Compose:

```bash
docker compose up -d
```

To specify a specific version and override what is configured in `.env`, specify
the `IMAGE_TAG`:

```bash
IMAGE_TAG=21.08.6 docker compose up -d
```

This will start up all containers in detached mode. You can monitor their status using:

```bash
docker compose ps
```

## 📝 Register the Cluster

After the containers are up and running, register the cluster with **SlurmDBD**:

```bash
./register_cluster.sh
```

> **Tip**: Wait a few seconds for the daemons to initialize before running the registration script to avoid connection errors like:
> `sacctmgr: error: Problem talking to the database: Connection refused`.

For real-time cluster logs, use:

```bash
docker compose logs -f
```

## 🖥️  Accessing the Cluster

To interact with the Slurm controller, open a shell inside the `slurmctld` container:

```bash
docker exec -it slurmctld bash
```

Now you can run any Slurm command from inside the container:

```bash
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 5-00:00:00      2   idle c[1-2]
```

## 🧑‍💻 Submitting Jobs

The cluster mounts the `slurm_jobdir` volume across all nodes, making job files accessible from the `/data` directory. To submit a job:

```bash
[root@slurmctld /]# cd /data/
[root@slurmctld data]# sbatch --wrap="hostname"
Submitted batch job 2
```

Check the output of the job:

```bash
[root@slurmctld data]# cat slurm-2.out
c1
```

## 🔄 Cluster Management

### Stopping and Restarting:

Stop the cluster without removing the containers:

```bash
docker compose stop
```

Restart it later:

```bash
docker compose start
```

### Deleting the Cluster:

To completely remove the containers and associated volumes:

```bash
docker compose down -v
```

## ⚙️ Advanced Configuration

You can modify Slurm configurations (`slurm.conf`, `slurmdbd.conf`) on the fly without rebuilding the containers. Just run:

```bash
./update_slurmfiles.sh slurm.conf slurmdbd.conf
docker compose restart
```

This makes it easy to add/remove nodes or test new configuration settings dynamically.

## 🤝 Contributing

Contributions are welcomed from the community! If you want to add features, fix bugs, or improve documentation:

1. Fork this repo.
2. Create a new branch: `git checkout -b feature/your-feature`.
3. Submit a pull request.

## 📄 License

This project is licensed under the [MIT License](LICENSE).
