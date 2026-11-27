# lsu

Run Linux Steam on FreeBSD with Linuxulator and a separately managed Linux root. lsu provides a launcher, runtime setup, and game compatibility tools.

## Requirements

- FreeBSD 15.1 or newer on amd64, with 32-bit and 64-bit Linux compatibility enabled.
- A glibc-based Linux root at `/compat/linux`, with Bash, graphics and audio support, 32-bit and 64-bit libraries, and a 32-bit loader. Libraries must be in `usr/lib32` or `usr/lib` for 32-bit and `usr/lib64` for 64-bit.
- A Linux compiler at `/compat/linux/bin/cc`, development headers, and working `-m32` and `-m64` support. On Void, install `gcc-multilib`, `glibc-devel-32bit`, and `libgcc-devel-32bit` in the Linux root.
- A configured FreeBSD ports tree. AMD graphics also require compatible Mesa drivers and Vulkan ICDs.

## Setup

Mount the Linux pseudo-filesystems, make sure `/compat/linux/dev/shm` is writable, and create `/compat/linux/etc/machine-id` if it is missing.

Run as root:

```sh
sysctl security.bsd.unprivileged_chroot=1
sysctl vfs.usermount=1
sysctl compat.linux.use_real_ifnames=1
kldload -n nullfs
```

For persistence, add `security.bsd.unprivileged_chroot=1` and `vfs.usermount=1` to `/etc/sysctl.conf`, add `compat.linux.use_real_ifnames=1` to `/etc/sysctl.kld.d/linux.conf`, and run `sysrc kld_list+=nullfs` as root.

**Security:** Unprivileged chroots and mounts relax host security. Run Steam as a dedicated non-wheel user.

## Installation

Build and install from this checkout:

```sh
make build
sudo make install
```

The port installs lsu in `/usr/local/steam-utils` and installs native dependencies. It does not install Steam or Linux dependencies. As the dedicated Steam user, run:

```sh
/usr/local/steam-utils/bin/lsu-bootstrap
steam
```

Steam downloads and updates its own files. Game compatibility tools may require additional Steam runtimes, Proton, or FreeBSD Wine.

## Limitations

Steam's browser sandbox is disabled, and pressure-vessel does not work. Game and controller support, streaming, VR, and anti-cheat are not guaranteed.

## License and credits

lsu is based on [linuxulator-steam-utils](https://github.com/shkhln/linuxulator-steam-utils). See [LICENSE](LICENSE) for copyright and license information.
