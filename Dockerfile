#ARG BASE_IMAGE
#FROM ${BASE_IMAGE}

FROM ubuntu:24.04

LABEL org.opencontainers.image.authors="andre.jernung@gu.se"

ARG MQ_VERSION=930

ENV TZ=Europe/Stockholm
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install --yes --no-install-recommends \
    bash \
    bc \
    ca-certificates \
    coreutils \
    debianutils \
    build-essential \
    file \
    findutils \
    gawk \
    grep \
    libc-bin \
    lsb-release \
    mount \
    passwd \
    procps \
    sed \
    tar \
    wget \
    uuid-dev \
    tk-dev \
    zlib1g-dev \
    liblzma-dev \
    libbz2-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libreadline6-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-pip \
    apt
#RUN echo "Remove shebang from /usr/bin/lsb_release to unblock pip (c.f. https://stackoverflow.com/q/44967202/5037799)"
#RUN sed -i 1d /usr/bin/lsb_release

#ta bort skit
RUN apt-get purge -y libx11.* 
#libqt.* libgtk.*
RUN apt-get autoremove -y

### Reworked docker image from https://developer.ibm.com/answers/questions/488740/running-mqclient-pymqi-in-docker/
###

# Download and extract the MQ installation files
ARG DIR_EXTRACT=/tmp/mq

ENV ARCHIVE_FILENAME=mqadv_dev${MQ_VERSION}_ubuntu_x86-64.tar.gz

# The URL to download the MQ installer from in tar.gz format
ARG MQ_URL=https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqadv/${ARCHIVE_FILENAME}

RUN echo $MQ_URL
RUN mkdir -p $DIR_EXTRACT && cd $DIR_EXTRACT

RUN wget --quiet $MQ_URL
RUN tar --ungzip --extract --file mqadv_dev${MQ_VERSION}_ubuntu_x86-64.tar.gz --directory $DIR_EXTRACT
RUN rm ${ARCHIVE_FILENAME}

# Recommended: Remove packages only needed by this script
RUN apt-get purge -y ca-certificates curl

# Recommended: Remove any orphaned packages
RUN apt-get autoremove -y --purge

# Recommended: Create the mqm user ID with a fixed UID and group, so that the file permissions work between different images
RUN groupadd --system --gid 599 mqm
RUN useradd --system --uid 599 --gid mqm mqm
RUN usermod -G mqm root

# The MQ packages to install
ARG MQ_PACKAGES="ibmmq-client ibmmq-sdk ibmmq-runtime"

# Find directory containing .deb files
ARG DIR_DEB=${DIR_EXTRACT}/MQServer

# Find location of mqlicense.sh
ARG MQLICENSE=${DIR_EXTRACT}/MQServer/mqlicense.sh

# Accept the MQ license
RUN ${MQLICENSE} -text_only -accept

RUN echo "deb [trusted=yes] file:${DIR_DEB} ./" > /etc/apt/sources.list.d/IBM_MQ.list

# Install MQ using the DEB packages
RUN apt-get update
RUN apt-get install -y $MQ_PACKAGES

# Remove 32-bit libraries from 64-bit container
RUN find /opt/mqm /var/mqm -type f -exec file {} \; | awk -F: '/ELF 32-bit/{print $1}' | xargs --no-run-if-empty rm -f

# Remove tar.gz files unpacked by RPM postinst scripts
RUN find /opt/mqm -name '*.tar.gz' -delete

# Recommended: Set the default MQ installation (makes the MQ commands available on the PATH)
RUN /opt/mqm/bin/setmqinst -p /opt/mqm -i

# Clean up all the downloaded files
RUN rm -f /etc/apt/sources.list.d/IBM_MQ.list

RUN rm -rf ${DIR_EXTRACT}

# Apply any bug fixes not included in base Ubuntu or MQ image.

# Don't upgrade everything based on Docker best practices https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#run
RUN apt-get upgrade -y sensible-utils

# End of bug fixes
RUN rm -rf /var/lib/apt/lists/*

# Optional: Update the command prompt with the MQ version
RUN echo "mq:$(dspmqver -b -f 2)" > /etc/debian_chroot && rm -rf /var/mqm

ENV LANGUAGE=en
ENV LANG=sv_SE.UTF-8
ENV LC_ALL=sv_SE.UTF-8

RUN export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/mqm/lib64/

# Support the latest functional cmdlevel by default
ENV MQ_QMGR_CMDLEVEL=802

# Always put the MQ data directory in a Docker volume
VOLUME /var/mqm
RUN chmod +x /var/mqm
RUN /opt/mqm/bin/dspmqinst
RUN apt-get update
RUN apt-get install python3-venv -y
RUN apt-get autoremove -y --purge
RUN useradd -ms /bin/bash pymqi
USER pymqi
WORKDIR /home/pymqi
RUN mkdir -p /home/pymqi/pymqienv
RUN python3 -m venv pymqienv
RUN . /home/pymqi/pymqienv/bin/activate && pip install pymqi
COPY pymqitest.py .
RUN . /home/pymqi/pymqienv/bin/activate && python3 pymqitest.py