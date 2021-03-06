#!/bin/bash
#
# WD hardware tools installer for Debian Stretch
#

SUDOERS=/etc/sudoers.d/wdhwd
CONFIG=/etc/wdhwd.conf
INSTALLDIR=/usr/local/lib/wdhwd
LOGDIR=/var/log/wdhwd
WDHWC=/usr/local/sbin/wdhwc

if hash pkgconfig 2>/dev/null; then
	SERVICE="$(pkg-config systemd --variable=systemdsystemunitdir)/wdhwd.service"
else
	# no need to install 100MB of dependencies for pkgconfig
	SERVICE=/lib/systemd/system/wdhwd.service
fi

echo "Check the model"
# TODO: analyse lspci to get the exact model
lscpu | grep N3710
if [[ ! $? -eq 0 ]]; then
	echo "Only the WD My Cloud PR2100 and PR4100 are currently supported in this installer"
    echo "Do not run this installer on a virtual machine"
	exit 1
fi

echo "Check that the 8250_lpss driver is loaded"
lspci -k -s 00:1e | grep 8250_lpss
if [[ ! $? -eq 0 ]]; then
	echo "The 8250_lpss driver is not loaded"
	echo "Here's how to get a valid kernel or the 8250_lpss module: https://community.wd.com/t/guide-how-to-install-debian-linux-on-the-my-cloud-pr4100-nas/217141/2"
	exit 1
fi

echo "Get the serial port"
PORT=/dev/$(dmesg | grep -m1 "irq = 19" | sed -e 's#.*\(ttyS[0-9]*\) .*#\1#')
echo "Found PMC module at serial port ${PORT}"

if [ "$(lsof -t $PORT)" = "" ]; then
	echo "LN1=Installing...\r" > ${PORT}
	echo "LN2=\r" > ${PORT}
else
    echo "WARNING: found processes using serial port ${PORT}: $(lsof -t ${PORT})"
fi

echo "Install wdhw tools dependencies"
apt install -y python3 python3-serial python3-smbus hddtemp

echo "Create wdhwd user"
id wdhwd
if [[ ! $? -eq 0 ]]; then
	useradd -r -U -M -b /var/run -s /usr/sbin/nologin wdhwd
fi
usermod -a -G dialout wdhwd

cp -f tools/wdhwd.sudoers ${SUDOERS}
chown root.root ${SUDOERS}
chmod ug=r,o= ${SUDOERS}

echo "Create wdhwd configuration file"
cp -f tools/wdhwd.conf ${CONFIG}
sed -i "s#^pmc_port=.*#pmc_port=${PORT}#" ${CONFIG}
chown root.root ${CONFIG}
chmod u=rw,go=r ${CONFIG}

echo "Install wdhwd"
[[ -d ${INSTALLDIR} ]] && rm -rf ${INSTALLDIR}
cp -dR . ${INSTALLDIR}
chown -R root.root ${INSTALLDIR}
chmod -R u=rwX,go=rX ${INSTALLDIR}
chmod -R u=rwx,go=rx ${INSTALLDIR}/scripts/*

mkdir -p ${LOGDIR}
chown root.wdhwd ${LOGDIR}
chmod -R ug=rwX,o=rX ${LOGDIR}

echo "Create client binary"
cat <<EOF > ${WDHWC}
#!/bin/bash
cd ${INSTALLDIR}
python3 -m wdhwdaemon.client "\$@"
EOF
chmod +x ${WDHWC}

echo "Register wdhwd in systemd"
cp tools/wdhwd.service ${SERVICE}
chown root.root ${SERVICE}
chmod u=rw,go=r ${SERVICE}

systemctl is-active wdhwd.service > /dev/null 2>&1
# these extra checks are handy when repeatedly installing the wdhwd service
if [[ $? -eq 0 ]]; then
	systemctl stop wdhwd.service
	sleep 5
	echo "Processes still using ${PORT}:"
	fuser -cv ${PORT}
fi
systemctl daemon-reload
systemctl enable wdhwd.service
systemctl start wdhwd.service
