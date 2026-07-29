# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Builds an image that stages the distribution the way the operator/injector does:
# the gem closure installed into a standalone bundle directory (not the app's
# default gem path), with the fixed entry symlink the injector requires. The app
# then runs with no Bundler and the gems available only via that mount.
#
# Parameterized by libc via the base image:
#   ruby:3.3-slim   (glibc)   ruby:3.3-alpine (musl)

ARG BASE=ruby:3.3-slim
FROM ${BASE}

WORKDIR /work

# A C toolchain is needed only at bundle-build time (the full closure briefly
# compiles a native gem, e.g. bigdecimal); the shipped/mounted bundle needs none.
RUN if command -v apt-get >/dev/null; then \
      apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null; then \
      apk add --no-cache build-base; \
    fi

# Install the distribution and its full dependency closure into a standalone
# bundle directory (the analog of the operator's mounted /otel-auto-instrumentation-ruby).
# Every transitive gem is pinned to the exact version recorded in Gemfile.lock
# (resolved via ./Gemfile against the gemspec) so the shipped closure is
# reproducible across builds instead of floating on whatever's newest on
# rubygems.org at build time. Update the pins with:
#   BUNDLE_GEMFILE=packaging/Gemfile bundle lock --update
COPY dash0-opentelemetry.gem /tmp/dash0-opentelemetry.gem
COPY Gemfile /tmp/packaging-Gemfile
COPY Gemfile.lock /tmp/packaging-Gemfile.lock
RUN BUNDLE_GEMFILE=/tmp/packaging-Gemfile ruby -rbundler -e ' \
      lockfile = Bundler::LockfileParser.new(File.read("/tmp/packaging-Gemfile.lock")); \
      pins = lockfile.specs.reject { |s| s.source.is_a?(Bundler::Source::Path) } \
                           .map { |s| "#{s.name}:#{s.version}" }.uniq; \
      File.write("/tmp/pins.txt", pins.join(" ")) \
    ' && \
    gem install --install-dir /otel-ruby --no-document --ignore-dependencies \
      $(cat /tmp/pins.txt) /tmp/dash0-opentelemetry.gem

# Create the fixed entry file name the injector requires (relative symlink so it
# survives being mounted elsewhere), pointing at the distribution's entry point.
RUN cd /otel-ruby && \
    ln -s "gems/$(ls gems | grep '^dash0-opentelemetry-')/lib/dash0-opentelemetry.rb" \
      opentelemetry-auto-instrumentation.rb

COPY mini_collector.rb app.rb plain_app.rb run.sh /work/
RUN chmod +x /work/run.sh

CMD ["/work/run.sh"]
