# Keep this tag in sync with the Ruby version in .ruby-version, so the Ruby
# installed in the container matches the one editors/tools (rbenv, ruby-lsp)
# resolve from .ruby-version.
FROM ghcr.io/rails/devcontainer/images/ruby:4.0.6

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

USER root

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends libvips ripgrep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER vscode

# [Optional] Uncomment this line to install additional gems.
# RUN su vscode -c "gem install <your-gem-names-here>"

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1
