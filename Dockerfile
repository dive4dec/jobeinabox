# Jobe-in-a-box: a Dockerised Jobe server (see https://github.com/trampgeek/jobe)
# With thanks to David Bowes (d.h.bowes@lancaster.ac.uk) who did all the hard work
# on this originally.

#FROM docker.io/ubuntu:22.04
FROM jupyter/scipy-notebook

USER root
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL \
    org.opencontainers.image.authors="richard.lobb@canterbury.ac.nz,j.hoedjes@hva.nl,d.h.bowes@herts.ac.uk" \
    org.opencontainers.image.title="JobeInABox" \
    org.opencontainers.image.description="JobeInABox" \
    org.opencontainers.image.documentation="https://github.com/trampgeek/jobeinabox" \
    org.opencontainers.image.source="https://github.com/trampgeek/jobeinabox"

# Set up the (apache) environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV LANG C.UTF-8

# Copy apache virtual host file for later use
COPY 000-jobe.conf /
# Copy test script
COPY container-test.sh /

# Set timezone
# Install extra packages
# Redirect apache logs to stdout
# Configure apache
# Configure php
# Get and install jobe
# Clean up
RUN apt-get update && \
    apt-get --no-install-recommends install -yq \
        acl \
        apache2 \
        build-essential \
        fp-compiler \
        git \
        libapache2-mod-php \
        nodejs \
        octave \
        openjdk-18-jdk \
        php \
        php-cli \
        php-mbstring \
        # python3 \
        # python3-pip \
        # python3-setuptools \
        sqlite3 \
        sudo \
        tzdata \
        unzip
        #unzip && \
    #python3 -m pip install pylint && \
    #pylint --reports=no --score=n --generate-rcfile > /etc/pylintrc && \

RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
    sed -i "s/export LANG=C/export LANG=$LANG/" /etc/apache2/envvars && \
    sed -i '1 i ServerName localhost' /etc/apache2/apache2.conf && \
    sed -i 's/ServerTokens\ OS/ServerTokens \Prod/g' /etc/apache2/conf-enabled/security.conf && \
    sed -i 's/ServerSignature\ On/ServerSignature \Off/g' /etc/apache2/conf-enabled/security.conf && \
    rm /etc/apache2/sites-enabled/000-default.conf && \
    mv /000-jobe.conf /etc/apache2/sites-enabled/ && \
    mkdir -p /var/crash && \
    chmod 777 /var/crash && \
    echo '<!DOCTYPE html><html lang="en"><title>Jobe</title><h1>Jobe</h1></html>' > /var/www/html/index.html && \
    git clone https://github.com/trampgeek/jobe.git /var/www/html/jobe && \
    apache2ctl start && \
    cd /var/www/html/jobe && \
    /usr/bin/python3 /var/www/html/jobe/install && \
    chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www/html && \
    apt-get -y autoremove --purge && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Expose apache
EXPOSE 80

# Healthcheck, minimaltest.py should complete within 2 seconds
HEALTHCHECK --interval=5m --timeout=2s \
    CMD /usr/bin/python3 /var/www/html/jobe/minimaltest.py || exit 1

# Start apache
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]


#install miniconda
RUN apt update -y && \
    apt upgrade -y && \
    apt install -y vim && \
    apt install -y libcap2-bin procps
    #apt install -y wget

# ENV CONDA_PATH /opt/conda
# RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
#      /bin/bash ~/miniconda.sh -b -p /opt/conda
# ENV PATH=$CONDA_PATH/bin:$PATH

# RUN conda init bash && \
#     . activate

# #install pakages to virtual env
# RUN conda create -n py310 python=3.10 && \
#     conda install -n py310 numpy -y && \ 
#     conda install -n py310 pandas -y

RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2 \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2ctl \
    && chown -R www-data:www-data /var/log/apache2 /var/run/apache2 \
    && usermod -a -G ${NB_GID} www-data

#Use conda python location
RUN echo '$config'"['python3_version'] = '${CONDA_DIR}/bin/python3';" >> /var/www/html/jobe/application/config/config.php
RUN sed -i 's\/usr/bin/\\' /var/www/html/jobe/application/libraries/python3_task.php

#Expand memory limit
RUN sed -i 's\600\6000\' /var/www/html/jobe/application/libraries/python3_task.php 

USER www-data