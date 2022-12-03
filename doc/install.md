Installation
============

Btrbk is a single perl script, and does not require any special
installation procedures or libraries. In order to install the btrbk
executable along with the documentation and an example configuration
file, choose one of the following methods:


### Generic Linux System

Install [asciidoctor] if you want to build the documentation.

Download and unpack the latest [btrbk source tarball] and type:

    sudo make install


### Debian Based Distros

btrbk is in debian stable (utils): https://packages.debian.org/stable/utils/btrbk

Packages are also available via NeuroDebian: http://neuro.debian.net/pkgs/btrbk.html


### Fedora Linux

btrbk is in the official Fedora repos: https://src.fedoraproject.org/rpms/btrbk

    sudo dnf install btrbk


### Arch Linux

btrbk is in AUR: https://aur.archlinux.org/packages/btrbk/


### Alpine Linux

btrbk is in the community repository

    apk add btrbk


### Gentoo Linux

btrbk is in portage:

    emerge app-backup/btrbk


### Void Linux

btrbk is in Void's `current` repository

    xbps-install -S btrbk


  [btrbk source tarball]: https://digint.ch/download/btrbk/releases/
  [asciidoctor]: https://asciidoctor.org
