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
if [ ! $? ]; then
	echo "Only the WD My Cloud PR2100 and PR4100 are currently supported in this installer"
	exit 1
fi

echo "Check that the 8250_lpss driver is loaded"
lspci -k -s 00:1e | grep 8250_lpss
if [ ! $? ]; then
	echo "The 8250_lpss driver is not loaded"
	echo "Look on the community.wd.com forum for more info"
	exit 1
fi

echo "Get the serial port"
port=/dev/$(dmesg | grep -m1 "irq = 19" | sed -e 's#.*\(ttyS[0-9]*\) .*#\1#')
echo "Found PMC module at serial port $port"

if "$(lsof -t $port)" -eq ""; then
	echo "LN1=Installing...\r" > $port
	echo "LN2=\r" > $port
fi

echo "Install wdhw tools dependencies"
apt install python3 python3-serial python3-smbus hddtemp

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
sed -i "s#^pmc_port=.*#pmc_port=$port#" ${CONFIG}
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
cp tools/wdhwd.service.no_root $SERVICE
chown root.root $SERVICE
chmod u=rw,go=r $SERVICE

systemctl is-active wdhwd.service 2>/dev/null
if [[ $? -eq 0 ]]; then
	systemctl stop wdhwd.service
	sleep 5
	echo "Processes still using $port:"
	fuser -cv $port
	systemctl daemon-reload
	systemctl enable wdhwd.service
	systemctl start wdhwd.service
else
	systemctl daemon-reload
	systemctl enable wdhwd.service
	systemctl start wdhwd.service
fi

