FROM buildpack-deps:focal

### base ###
RUN yes | unminimize \
    && apt-get install -yq \
        zip \
        unzip \
        bash-completion \
        build-essential \
        htop \
        jq \
        less \
        locales \
        man-db \
        nano \
        software-properties-common \
        sudo \
        time \
        vim \
        multitail \
        lsof \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

ENV LANG=en_US.UTF-8

### Git ###
RUN add-apt-repository -y ppa:git-core/ppa \
    && apt-get install -yq git \
    && rm -rf /var/lib/apt/lists/*

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    # passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
ENV HOME=/home/gitpod
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

### Gitpod user (2) ###
USER gitpod
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success" && \
    mkdir /home/gitpod/.bashrc.d && \
    (echo; echo "for i in \$(ls \$HOME/.bashrc.d/*); do source \$i; done"; echo) >> /home/gitpod/.bashrc

### Install C/C++ compiler and associated tools ###
USER root
RUN curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
    && echo "deb https://apt.llvm.org/focal/ llvm-toolchain-focal main" >> /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -yq \
        clang-format \
        clang-tidy \
        # clang-tools \ # breaks the build atm
        clangd \
        gdb \
        lld \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

### Apache, PHP and Nginx ###
USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq \
        apache2 \
        nginx \
        nginx-extras \
        composer \
        php \
        php-all-dev \
        php-bcmath \
        php-ctype \
        php-curl \
        php-date \
        php-gd \
        php-intl \
        php-json \
        php-mbstring \
        php-mysql \
        php-net-ftp \
        php-pgsql \
        php-sqlite3 \
        php-tokenizer \
        php-xml \
        php-zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* \
    && mkdir /var/run/nginx \
    && ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load \
    && chown -R gitpod:gitpod /etc/apache2 /var/run/apache2 /var/lock/apache2 /var/log/apache2 \
    && chown -R gitpod:gitpod /etc/nginx /var/run/nginx /var/lib/nginx/ /var/log/nginx/
COPY --chown=gitpod:gitpod apache2/ /etc/apache2/
COPY --chown=gitpod:gitpod nginx /etc/nginx/

## The directory relative to your git repository that will be served by Apache / Nginx
ENV APACHE_DOCROOT_IN_REPO="public" \
    NGINX_DOCROOT_IN_REPO="public"

### Homebrew ###
USER gitpod
RUN mkdir ~/.cache && sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
ENV PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin/" \
    MANPATH="$MANPATH:/home/linuxbrew/.linuxbrew/share/man" \
    INFOPATH="$INFOPATH:/home/linuxbrew/.linuxbrew/share/info" \
    HOMEBREW_NO_AUTO_UPDATE=1
RUN sudo apt-get remove -y cmake \
    && brew install cmake

### Go ###
USER gitpod
ENV GO_VERSION=1.14 \
    GOPATH=$HOME/go-packages \
    GOROOT=$HOME/go
ENV PATH=$GOROOT/bin:$GOPATH/bin:$PATH
RUN curl -fsSL https://storage.googleapis.com/golang/go$GO_VERSION.linux-amd64.tar.gz | tar xzs && \
# install VS Code Go tools from https://github.com/Microsoft/vscode-go/blob/0faec7e5a8a69d71093f08e035d33beb3ded8626/src/goInstallTools.ts#L19-L45
    go get -u -v \
        github.com/mdempsky/gocode \
        github.com/uudashr/gopkgs/cmd/gopkgs \
        github.com/ramya-rao-a/go-outline \
        github.com/acroca/go-symbols \
        golang.org/x/tools/cmd/guru \
        golang.org/x/tools/cmd/gorename \
        github.com/fatih/gomodifytags \
        github.com/haya14busa/goplay/cmd/goplay \
        github.com/josharian/impl \
        github.com/tylerb/gotype-live \
        github.com/rogpeppe/godef \
        github.com/zmb3/gogetdoc \
        golang.org/x/tools/cmd/goimports \
        github.com/sqs/goreturns \
        winterdrache.de/goformat/goformat \
        golang.org/x/lint/golint \
        github.com/cweill/gotests/... \
        github.com/alecthomas/gometalinter \
        honnef.co/go/tools/... \
        github.com/golangci/golangci-lint/cmd/golangci-lint \
        github.com/mgechev/revive \
        github.com/sourcegraph/go-langserver \
        github.com/go-delve/delve/cmd/dlv \
        github.com/davidrjenni/reftools/cmd/fillstruct \
        github.com/godoctor/godoctor && \
    GO111MODULE=on go get -u -v \
        golang.org/x/tools/gopls@latest && \
    go get -u -v -d github.com/stamblerre/gocode && \
    go build -o $GOPATH/bin/gocode-gomod github.com/stamblerre/gocode && \
    rm -rf $GOPATH/src && \
    sudo rm -rf $GOPATH/pkg && \
    rm -rf /home/gitpod/.cache/go
# user Go packages
ENV GOPATH=/workspace/go \
    PATH=/workspace/go/bin:$PATH

### Java ###
## Place '.gradle' and 'm2-repository' in /workspace because (1) that's a fast volume, (2) it survives workspace-restarts and (3) it can be warmed-up by pre-builds.
USER gitpod
RUN curl -fsSL "https://get.sdkman.io" | bash \
 && bash -c ". /home/gitpod/.sdkman/bin/sdkman-init.sh \
             && sdk install java 11.0.6.fx-zulu \
             && sdk install gradle \
             && sdk install maven \
             && sdk flush archives \
             && sdk flush temp \
             && mkdir /home/gitpod/.m2 \
             && printf '<settings>\n  <localRepository>/workspace/m2-repository/</localRepository>\n</settings>\n' > /home/gitpod/.m2/settings.xml \
             && echo 'export SDKMAN_DIR=\"/home/gitpod/.sdkman\"' >> /home/gitpod/.bashrc.d/99-java \
             && echo '[[ -s \"/home/gitpod/.sdkman/bin/sdkman-init.sh\" ]] && source \"/home/gitpod/.sdkman/bin/sdkman-init.sh\"' >> /home/gitpod/.bashrc.d/99-java"
# above, we are adding the sdkman init to .bashrc (executing sdkman-init.sh does that), because one is executed on interactive shells, the other for non-interactive shells (e.g. plugin-host)
ENV GRADLE_USER_HOME=/workspace/.gradle/

### Node.js ###
USER gitpod
ENV NODE_VERSION=12.16.2
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | PROFILE=/dev/null bash \
    && bash -c ". .nvm/nvm.sh \
        && nvm install $NODE_VERSION \
        && nvm alias default $NODE_VERSION \
        && npm install -g npm typescript yarn" \
    && echo ". ~/.nvm/nvm-lazy.sh"  >> /home/gitpod/.bashrc.d/50-node
# above, we are adding the lazy nvm init to .bashrc, because one is executed on interactive shells, the other for non-interactive shells (e.g. plugin-host)
COPY --chown=gitpod:gitpod nvm-lazy.sh /home/gitpod/.nvm/nvm-lazy.sh
ENV PATH=$PATH:/home/gitpod/.nvm/versions/node/v${NODE_VERSION}/bin

USER gitpod
ENV PATH=$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH
RUN curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash \
    && { echo; \
        echo 'eval "$(pyenv init -)"'; \
        echo 'eval "$(pyenv virtualenv-init -)"'; } >> /home/gitpod/.bashrc.d/60-python \
    && pyenv update \
    && pyenv install 2.7.17 \
    && pyenv install 3.8.2 \
    && pyenv global 2.7.17 3.8.2 \
    && python2 -m pip install --upgrade pip \
    && python3 -m pip install --upgrade pip \
    && python3 -m pip install --upgrade \
        setuptools wheel virtualenv pipenv pylint rope flake8 \
        mypy autopep8 pep8 pylama pydocstyle bandit notebook \
        twine \
    && sudo rm -rf /tmp/*
# Gitpod will automatically add user site under `/workspace` to persist your packages.
# ENV PYTHONUSERBASE=/workspace/.pip-modules \
#    PIP_USER=yes

USER gitpod
RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import - \
    && curl -sSL https://rvm.io/pkuczynski.asc | gpg --import - \
    && curl -fsSL https://get.rvm.io | bash -s stable \
    && bash -lc " \
        rvm requirements \
        && rvm install 2.5 \
        && rvm install 2.6 \
        && rvm use 2.6 --default \
        && rvm rubygems current \
        && gem install bundler --no-document \
        && gem install solargraph --no-document" \
    && echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*' >> /home/gitpod/.bashrc.d/70-ruby
ENV GEM_HOME=/workspace/.rvm

USER gitpod
RUN sudo apt-get update \
    && DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq \
        # Enable Rust static binary builds
        musl \
        musl-dev \
        musl-tools \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/* /tmp/*

RUN cp /home/gitpod/.profile /home/gitpod/.profile_orig && \
    curl -fsSL https://sh.rustup.rs | sh -s -- -y \
    && .cargo/bin/rustup toolchain install 1.42.0 \
    && .cargo/bin/rustup default 1.42.0 \
    # Save image size by removing now-redudant stable toolchain
    && .cargo/bin/rustup toolchain uninstall stable \
    && .cargo/bin/rustup component add \
        rls \
        rust-analysis \
        rust-src \
    && .cargo/bin/rustup completions bash | sudo tee /etc/bash_completion.d/rustup.bash-completion > /dev/null \
    && .cargo/bin/rustup target add x86_64-unknown-linux-musl \
    && grep -v -F -x -f /home/gitpod/.profile_orig /home/gitpod/.profile > /home/gitpod/.bashrc.d/80-rust

RUN bash -lc "cargo install cargo-watch cargo-edit cargo-tree"

USER gitpod