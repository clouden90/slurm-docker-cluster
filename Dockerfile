FROM rockylinux:8

LABEL org.opencontainers.image.source="https://github.com/yichengt900/slurm-docker-cluster" \
      org.opencontainers.image.title="slurm-mom6-cluster" \
      org.opencontainers.image.description="Slurm Docker cluster with MOM6 dependencies on Rocky Linux 8" \
      org.label-schema.docker.cmd="docker-compose up -d" \
      maintainer="Yi-Cheng Teng"

# --- Base Setup and Dependencies ---
RUN set -ex \
    && dnf -y update \
    && dnf -y install dnf-plugins-core \
    && dnf config-manager --set-enabled powertools \
    # Install EPEL first in its own layer
    && dnf -y install epel-release \
    # Clean cache BEFORE making a new one with EPEL enabled
    && dnf clean all

# Make cache AFTER EPEL is installed
RUN dnf makecache

# Group 1: Core build tools & Slurm deps (using dnf)
RUN set -ex && dnf -y install \
    wget bzip2 perl gcc gcc-c++ gcc-gfortran git gnupg make \
    munge munge-devel python3-devel python3-pip \
    mariadb-server mariadb-devel psmisc bash-completion \
    vim-enhanced http-parser-devel json-c-devel

# Group 2: MPI (using dnf)
RUN set -ex && dnf -y install \
    openmpi openmpi-devel

# Group 3: NetCDF (using dnf - trying again now that EPEL should be active)
RUN set -ex && dnf -y install \
    netcdf netcdf-devel netcdf-fortran-devel

# Group 4: Other Utils & Build tools (using dnf)
RUN set -ex && dnf -y install \
    curl tcsh autoconf automake libtool \
    ImageMagick nco ncview 

# Final cleanup
RUN set -ex && dnf clean all \
    && rm -rf /var/cache/dnf

RUN alternatives --set python /usr/bin/python3

RUN pip3 install --upgrade pip setuptools

# Install build dependencies like Cython and Numpy first
RUN pip3 install --no-cache-dir \
    Cython \
    numpy

# Now install the rest of the packages
RUN pip3 install --no-cache-dir \
    pytest \
    netCDF4 \
    matplotlib \
    xarray

ARG GOSU_VERSION=1.17

RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

ARG SLURM_TAG

RUN set -x \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd \
    && rm -rf slurm

# --- Build and Install FRE-NCtools (from MOM6 Dockerfile, adapted) ---
# Note: Installing system-wide instead of as 'builder' user for simplicity
# Adjust paths and commands if necessary
RUN mkdir -p /opt/build_fre && cd /opt/build_fre && git clone -b 2024.04 https://github.com/NOAA-GFDL/FRE-NCtools.git
RUN cd /opt/build_fre/FRE-NCtools && autoreconf -i && mkdir build && cd build \
    && export CPPFLAGS="-I/usr/include" \
    && export LDFLAGS="-L/usr/lib64" \
    && export FFLAGS="-I/usr/include" \
    && ../configure --prefix=/usr/local \
    && make && make install
# Cleanup build directory
RUN rm -rf /opt/build_fre

# --- Slurm Configuration (from original Slurm Dockerfile) ---
RUN set -x \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN set -x \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf


COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
