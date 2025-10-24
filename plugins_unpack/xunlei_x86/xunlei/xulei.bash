mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/downloads
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/proc
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/sys
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/dev
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/lib
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/lib64
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/bin
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/usr
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/var
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/tmp
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/run
mkdir -p /etc/log/chroot_xunlei/tmp/xunlei/data



mount --bind "/dev" "/etc/log/chroot_xunlei/dev"

chroot /etc/log/chroot_xunlei /bin/xlp --dashboard_port 2345 --dir_download /xunlei/downloads --dir_data /xunlei/data --prevent_update --chroot /tmp/xunlei



mkdir -p /tmp/xunlei/downloads
mkdir -p /tmp/xunlei/proc
mkdir -p /tmp/xunlei/sys
mkdir -p /tmp/xunlei/dev
mkdir -p /tmp/xunlei/lib
mkdir -p /tmp/xunlei/lib64
mkdir -p /tmp/xunlei/bin
mkdir -p /tmp/xunlei/usr
mkdir -p /tmp/xunlei/var
mkdir -p /tmp/xunlei/tmp
mkdir -p /tmp/xunlei/run
mkdir -p /tmp/xunlei/data

mount --bind /proc /tmp/xunlei/proc
mount --bind /sys /tmp/xunlei/sys
mount --bind /dev /tmp/xunlei/dev
mount --bind /proc /tmp/xunlei/proc
mount --bind /sys /tmp/xunlei/sys


mount --bind /etc/log/chroot_xunlei/bin /tmp/xunlei/bin
mount --bind /etc/log/chroot_xunlei/usr /tmp/xunlei/usr
mount --bind /etc/log/chroot_xunlei/lib /tmp/xunlei/lib
mount --bind /etc/log/chroot_xunlei/lib64 /tmp/xunlei/lib64


mount --bind /sys /etc/log/chroot_xunlei/sys
mount --bind /proc /etc/log/chroot_xunlei/proc
mount --bind /dev /etc/log/chroot_xunlei/dev



tar -xvf /tmp/layer1.tar -C /etc/log/chroot_xunlei
tar -xvf /tmp/layer2.tar -C /etc/log/chroot_xunlei
cp /etc/log/chroot_xunlei/bin/xlp /tmp/xlp

mkdir -p /tmp/xunlei/downloads
mkdir -p /tmp/xunlei/proc
mkdir -p /tmp/xunlei/sys
mkdir -p /tmp/xunlei/dev
mkdir -p /tmp/xunlei/lib
mkdir -p /tmp/xunlei/lib64
mkdir -p /tmp/xunlei/bin
mkdir -p /tmp/xunlei/usr
mkdir -p /tmp/xunlei/var
mkdir -p /tmp/xunlei/tmp
mkdir -p /tmp/xunlei/run
mkdir -p /tmp/xunlei/data

mount --bind /proc /tmp/xunlei/proc
mount --bind /sys /tmp/xunlei/sys
mount --bind /dev /tmp/xunlei/dev
mount --bind /proc /tmp/xunlei/proc
mount --bind /sys /tmp/xunlei/sys


/tmp/xlp --dashboard_port 2345 --dir_download /xunlei/downloads --dir_data /xunlei/data --prevent_update --chroot /tmp/xunlei


docker exec -it 4eec105ef94e /bin/bash




mkdir -p /tmp/xunlei/downloads
mkdir -p /tmp/xunlei/proc
mkdir -p /tmp/xunlei/sys
mkdir -p /tmp/xunlei/dev
mkdir -p /tmp/xunlei/lib

mkdir -p /tmp/xunlei/bin
mkdir -p /tmp/xunlei/usr
mkdir -p /tmp/xunlei/var
mkdir -p /tmp/xunlei/tmp
mkdir -p /tmp/xunlei/run
mkdir -p /tmp/xunlei/data

mount --bind /proc /tmp/xunlei/proc
mount --bind /sys /tmp/xunlei/sys
mount --bind /dev /tmp/xunlei/dev
mount --bind /proc /tmp/xunlei/proc
mount --bind /sys /tmp/xunlei/sys


mount --bind /etc/log/chroot_xunlei/bin /tmp/xunlei/bin
mount --bind /etc/log/chroot_xunlei/usr /tmp/xunlei/usr
mount --bind /etc/log/chroot_xunlei/lib /tmp/xunlei/lib
mount --bind /etc/log/chroot_xunlei/lib64 /tmp/xunlei/lib64


mkdir -p /tmp/xunlei/lib64




	linux-vdso.so.1 (0x00007ffd113fb000)
	libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x0000790d13373000)
	libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x0000790d1336e000)
	libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x0000790d13000000)
	libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x0000790d13369000)
	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x0000790d13345000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x0000790d12c00000)
	/lib64/ld-linux-x86-64.so.2 (0x0000790d1346f000)


ldd xunlei-pan-cli-launcher.amd64 
	linux-vdso.so.1 (0x00007ffc74319000)
	libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f9599a62000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f9599800000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f9599a7c000)



docker exec -it 1bd4a7671da9 /bin/bash
/var/packages/pan-xunlei-com/target/var/pan-xunlei-com/data/.drive/bin/xunlei-pan-cli.3.21.0.amd64



mkdir /lib/apt
mkdir /lib/dpkg
mkdir /lib/init
mkdir /lib/locale
mkdir /lib/lsb
mkdir /lib/mime
mkdir /lib/sysctl.d
mkdir /lib/systemd
mkdir /lib/terminfo
mkdir /lib/tmpfiles.d
mkdir /lib/udev
mkdir /lib/x86_64-linux-gnu



mount --bind /etc/log/chroot_xunlei/lib/apt /lib/apt
mount --bind /etc/log/chroot_xunlei/lib/dpkg /lib/dpkg
mount --bind /etc/log/chroot_xunlei/lib/init /lib/init
mount --bind /etc/log/chroot_xunlei/lib/locale /lib/locale
mount --bind /etc/log/chroot_xunlei/lib/lsb /lib/lsb
mount --bind /etc/log/chroot_xunlei/lib/mime /lib/mime
mount --bind /etc/log/chroot_xunlei/lib/sysctl.d /lib/sysctl.d
mount --bind /etc/log/chroot_xunlei/lib/terminfo /lib/terminfo
mount --bind /etc/log/chroot_xunlei/lib/tmpfiles.d /lib/tmpfiles.d
mount --bind /etc/log/chroot_xunlei/lib/udev /lib/udev
mount --bind /etc/log/chroot_xunlei/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu



chroot /etc/log/chroot_xunlei /bin/xlp --dashboard_port 2345 --dir_download /xunlei/downloads --dir_data /xunlei/data --prevent_update --chroot /xunlei




mkdir /etc/log/syncthing -p
tar -xvf /tmp/layer1.tar -C /etc/log/syncthing
tar -xvf /tmp/layer2.tar -C /etc/log/syncthing
tar -xvf /tmp/layer3.tar -C /etc/log/syncthing
tar -xvf /tmp/layer4.tar -C /etc/log/syncthing
tar -xvf /tmp/layer5.tar -C /etc/log/syncthing



touch /etc/log/syncthing/dev/null
chroot /etc/log/syncthing env HOME=/root /bin/syncthing serve --gui-address=0.0.0.0:8384 >/dev/null &