FROM centos:8

ENV PCP_REPO=https://github.com/performancecopilot/pcp.git
ENV PCP_VERSION=a575d19afa9abb105e3fccfc73a5e0c543a5cbda
ENV GRAFANA_PCP_REPO=https://github.com/performancecopilot/grafana-pcp.git
ENV GRAFANA_PCP_VERSION=b5157b32e035b5b95cac7dac77d6fed7c41464b2

# Import archive signing key and update packages
RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial \
    && rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg \
    && dnf update -y

# Install needed dependencies
RUN dnf install -y epel-release dnf-utils \
    && rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8 \
    && dnf config-manager --set-enabled PowerTools \
    && dnf config-manager --add-repo https://dl.yarnpkg.com/rpm/yarn.repo \
    && dnf install -y --setopt=tsflags=nodocs \
        autoconf bison flex make gcc gcc-c++ \
        bc git man which setools-console yarn \
        selinux-policy-devel selinux-policy-targeted \
        rpm-build redhat-rpm-config initscripts \
        avahi-devel ncurses-devel nss-devel \
        readline-devel systemd-devel xz-devel \
        openssl-devel python2-devel python3-devel \
        perl-devel perl-Digest-MD5 perl-ExtUtils-MakeMaker \
        perl-generators perl-JSON perl-libwww-perl \
        perl-Time-HiRes postfix-perl-scripts \
    && dnf install -y https://downloads.redhat.com/redhat/rhel/rhel-8-beta/appstream/x86_64/Packages/libuv-devel-1.23.1-1.el8.x86_64.rpm

# Install PCP
RUN git clone ${PCP_REPO} /pcp
WORKDIR /pcp
RUN git checkout ${PCP_VERSION}
RUN ./Makepkgs --verbose --without-qt --without-qt3d --without-manager

# Install PCP Grafana plugin
RUN git clone ${GRAFANA_PCP_REPO} /grafana-pcp
WORKDIR /grafana-pcp
RUN git checkout ${GRAFANA_PCP_VERSION}
RUN yarn install \
    && yarn build


FROM centos:8
COPY --from=0 /pcp/pcp-*/build/rpm /pcp-rpms
COPY --from=0 /grafana-pcp/dist /var/lib/grafana/plugins/grafana-pcp
COPY grafana.repo /etc/yum.repos.d/grafana.repo
COPY datasource.yaml /etc/grafana/provisioning/datasources/grafana-pcp.yaml
COPY grafana-configuration.service /etc/systemd/system

# Import archive signing key and update packages
RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial \
    && rpm --import https://packages.grafana.com/gpg.key \
    && dnf update -y

# Install PCP, Redis and Grafana
RUN dnf -y install --setopt=tsflags=nodocs \
        redis grafana \
        $(ls /pcp-rpms/pcp-{5,libs-5,conf,selinux}*.x86_64.rpm) \
    && dnf clean all \
    && systemctl enable redis pmcd pmlogger pmproxy grafana-server grafana-configuration

CMD ["/usr/sbin/init"]
