FROM docker.io/library/archlinux:base-devel AS pacstrap

# Automatically use build date (in format YYYY/MM/DD) or allow manual override
# Should keep the images up to date.
ARG BUILD_DATE
ENV ARCHIVE_DATE=${BUILD_DATE:-$(date +%Y/%m/%d)}
ARG ARCHIVE_SERVER=https://archive.archlinux.org/repos

RUN pacman-key --init
RUN pacman -Sy --needed --noconfirm archlinux-keyring arch-install-scripts

WORKDIR /

COPY pacstrap-docker /usr/bin

# Generate pacman.conf dynamically
RUN bash -c "cat > /etc/pacman.conf" <<EOF
[options]
Architecture = auto
ParallelDownloads = 6
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Never

[core]
Server = ${ARCHIVE_SERVER}/${ARCHIVE_DATE}/core/os/\$arch

[extra]
Server = ${ARCHIVE_SERVER}/${ARCHIVE_DATE}/extra/os/\$arch

[multilib]
Server = ${ARCHIVE_SERVER}/${ARCHIVE_DATE}/multilib/os/\$arch
EOF

RUN cat /etc/pacman.conf

RUN rm -rf /rootfs && mkdir /rootfs
RUN pacstrap-docker /rootfs base

FROM scratch as root

COPY --from=pacstrap /rootfs/ /

LABEL supports-commonarch="true" \
      name="CommonArch Base Image" \
      usage="This image is meant to be used on CommonArch" \
      summary="Base image for creating CommonArch Desktop images" \
      maintainer="Rudra Saraswat <rswat09@gmail.com>"

# Install extra packages
COPY extra-packages /
RUN pacman -Syu --needed --noconfirm - < extra-packages && rm /extra-packages

# Install and enable NetworkManager and BlueZ
RUN pacman -Syu --needed --noconfirm networkmanager bluez
RUN systemctl enable NetworkManager && systemctl enable bluetooth

# Clean up cache
RUN yes | pacman -Scc

# Enable sudo for wheel group
RUN echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
