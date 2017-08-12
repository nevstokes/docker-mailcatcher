FROM alpine:3.5
MAINTAINER Nev Stokes <mail@nevstokes.com>

ARG BUILD_DATE
ARG VCS_REF
ARG VCS_URL
ARG VERSION

# smtp port
EXPOSE 1025

# webserver port
EXPOSE 1080

ENTRYPOINT ["mailcatcher", "-f", "--ip=0.0.0.0"]

RUN set -ex \
  \
  # Pre-build state
  && find / \( -type f -o -type l \) | sort > /tmp/files.before \
  \
  # Config
  && RUBY_CERT="https://raw.githubusercontent.com/rubygems/rubygems/master/lib/rubygems/ssl_certs/index.rubygems.org/GlobalSignRootCA.pem" \
  \
  # Prep
  && apk update \
  && apk add --no-cache --virtual .build-deps \
    ca-certificates \
    build-base \
    libressl \
    libressl-dev \
    ruby-dev \
    sqlite-dev \
  \
  # Run deps
  && apk add --no-cache \
    libstdc++ \
    ruby \
    ruby-bigdecimal \
    ruby-io-console \
    ruby-json \
    sqlite \
  \
  # Get Rubygems certificate
  && rubyCertDir="$(dirname `gem which rubygems`)/ssl_certs/" \
  && mkdir $rubyCertDir \
  && wget -P $rubyCertDir $RUBY_CERT \
  \
  # Install
  && gem install mailcatcher json --no-rdoc --no-ri \
  \
  # Tidy up
  && gem uninstall did_you_mean minitest power_assert rake test-unit \
  && apk del --purge .build-deps \
  && rm -rf /var/cache/apk \
  \
  # terminfo not needed
  && rm -rf /etc/terminfo /usr/share/terminfo \
  \
  # Create post-build state for comparison
  && find / \( -type f -o -type l \) | sort > /tmp/files.after \
  \
  # New files
  && comm -13 /tmp/files.before /tmp/files.after | grep -v -E "/proc/|/sys/|/tmp/" > /files.diff \
  \
  # Updated files (ignoring diff file)
  && find / \( -type f -o -type l \) -newer /tmp/files.before | grep -v -E "/files\.diff|/proc/|/sys/|/tmp/" >> /files.diff \
  \
  # Required libraries
  && ldd `which ruby` | awk '/statically/{next;} /=>/ { print $3; next; } { print $1 }' | sort -u >> /files.diff \
  \
  # Sort and unique
  && sort -u /files.diff > /files.$$ && mv /files.$$ /files.diff \
  \
  # Make sure the diff file gets cleaned up
  && echo "/files.diff" >> /tmp/files.after \
  \
  # Get rid of everything that we can
  && comm -13 /files.diff /tmp/files.after | grep -E -v "^/(etc|lib|proc|sys)/" | xargs rm -rf

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.schema-version="1.0" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.version=$VERSION

