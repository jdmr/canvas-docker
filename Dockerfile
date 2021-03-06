FROM ubuntu

MAINTAINER David Mendoza <jdmendoza@swau.edu>

ENV POSTGRES_VERSION 9.3
ENV RAILS_ENV production

# enable https repos and add in nodesource repo
RUN apt-get -y install apt-transport-https
COPY assets/nodesource.list /etc/apt/sources.list.d/nodesource.list
ADD https://deb.nodesource.com/gpgkey/nodesource.gpg.key /tmp/nodesource.gpg.key
RUN apt-key add /tmp/nodesource.gpg.key

# add nodejs and recommended ruby repos
RUN apt-get update \
    && apt-get -y install software-properties-common python-software-properties \
    && add-apt-repository ppa:brightbox/ppa \
    && add-apt-repository ppa:brightbox/ruby-ng \
    && apt-get update

# install deps for building/running canvas
RUN apt-get install -y \
    ruby2.1 ruby2.1-dev zlib1g-dev libxml2-dev libxslt1-dev \
    imagemagick libpq-dev libxmlsec1-dev libcurl4-gnutls-dev \
    libxmlsec1 build-essential openjdk-7-jre unzip curl \
    python g++ make git-core nodejs supervisor \
    libpq5 libsqlite3-dev \
    postgresql-client-$POSTGRES_VERSION \
    && apt-get clean \
    && rm -Rf /var/cache/apt

RUN gem install bundler --version 1.10.3

# Set the locale to avoid active_model_serializers bundler install failure
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# install canvas
RUN cd /opt \
    && git clone https://github.com/instructure/canvas-lms.git \
    && cd /opt/canvas-lms \
    && bundle install --path vendor/bundle --without="mysql"

# config setup
RUN cd /opt/canvas-lms \
    && for config in amazon_s3 delayed_jobs domain file_store outgoing_mail security external_migration \
       ; do cp config/$config.yml.example config/$config.yml \
       ; done

RUN cd /opt/canvas-lms \
    && npm install --unsafe-perm \
    && bundle exec rake canvas:compile_assets

COPY assets/database.yml /opt/canvas-lms/config/database.yml
COPY assets/redis.yml /opt/canvas-lms/config/redis.yml
COPY assets/cache_store.yml /opt/canvas-lms/config/cache_store.yml
COPY assets/supervisord.conf /etc/supervisor/supervisord.conf
COPY assets/dbinit.sh /dbinit.sh
RUN chmod 755 /dbinit.sh

RUN /dbinit.sh

# canvas
EXPOSE 3000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
