FROM phusion/baseimage:0.9.16

# openjdk is deliberately old. It works with DITA-OT 1.7. Newer DITA-OT needs Oracle.
RUN     apt-get update && apt-get install -y \
            build-essential \
            curl \
            git \
            libfontconfig1 \
            libjpeg8 \
            libssl-dev \
            libxrender1 \
            openjdk-6-jdk \
            sed \
            fontconfig \
            wget \
            silversearcher-ag

RUN     wget -O cf_cli.deb 'https://cli.run.pivotal.io/stable?release=debian64&version=6.22.0&source=github-rel'
RUN     dpkg -i cf_cli.deb
RUN     wget -O ruby-install-0.7.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.7.0.tar.gz && \
            tar -xzvf /ruby-install-0.7.0.tar.gz && \
            cd ruby-install-0.7.0 && \
            make install

RUN     ruby-install ruby 2.5.3

RUN     locale-gen en_US.UTF-8

RUN     groupadd -r setupuser && useradd -r -g setupuser setupuser
RUN     chown -R setupuser:setupuser /opt/rubies

RUN     ssh-keyscan -H github.com >> /etc/ssh/ssh_known_hosts


USER    setupuser

ENV     PATH /opt/rubies/ruby-2.5.3/bin:$PATH

ENV     HOME /tmp/build
RUN     mkdir /tmp/build
WORKDIR /tmp/build

ENV     LC_ALL en_US.UTF-8

# Install Ant from upstream distribution, fixes https://github.com/dita-ot/dita-ot/issues/1613
RUN     wget -O ~/ant.tar.bz2 http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.4-bin.tar.bz2
RUN     tar -jxf ant.tar.bz2
ENV     PATH /tmp/build/apache-ant-1.9.4/bin/:$PATH

# Install PhantomJS
RUN     wget -O ~/phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2
RUN     tar -jxf phantomjs.tar.bz2
ENV     PATH /tmp/build/phantomjs-2.1.1-linux-x86_64/bin:/$PATH

# Install old version of DITA-OT that works with our ditamaps
RUN     wget -O dita-ot-1.7.5.tar.gz https://github.com/dita-ot/dita-ot/archive/1.7.5.tar.gz && \
            tar -zxf dita-ot-1.7.5.tar.gz
WORKDIR dita-ot-1.7.5
RUN     ant jar
RUN     ant -f src/main/integrator.xml

# Export path to DITA-OT for Bookbinder
ENV     PATH_TO_DITA_OT_LIBRARY $HOME/dita-ot-1.7.5/src/main

# PLEASE NOTE: Some versions of bundler (notably 1.12.5) have caused failures in the test suite. 
RUN     gem install bundler -v 1.17.3 --no-document

USER    root
