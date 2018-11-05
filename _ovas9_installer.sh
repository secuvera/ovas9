#!/bin/bash

BASE=openvas
NOCERT="--no-check-certificate"
GSA="greenbone-security-assistant-"
HINT="*"
RED='\033[0;31m'
GRE='\033[0;32m'
NOC='\033[0m'

declare -a _package_list=("-libraries-" "-scanner-" "-manager-" "-cli-" "-smb-")

echo " "
echo -e " ${GRE} ---------- DOWNLOADING DEPENDENCIES ---------- ${NOC} "
  apt install -y build-essential cmake gcc-mingw-w64 libgnutls28-dev perl-base heimdal-dev libpopt-dev libglib2.0-dev python-setuptools python-polib checkinstall libssh-dev libpcap-dev libxslt1-dev libgpgme11-dev uuid-dev bison libksba-dev libhiredis-dev libsnmp-dev libgcrypt20-dev libldap2-dev  libfreeradius-client-dev doxygen xmltoman sqlfairy sqlite3 redis-server gnutls-bin libsqlite3-dev texlive texlive-lang-german texlive-lang-english texlive-latex-recommended texlive-latex-extra libmicrohttpd-dev libxml2-dev libxslt1.1 xsltproc flex clang nmap rpm nsis alien

sleep 10

echo " "
echo -e " ${GRE} ---------- DOWNLOADING SOURCES ---------- ${NOC} "
wget http://wald.intevation.org/frs/download.php/2420/openvas-libraries-9.0.1.tar.gz ${NOCERT}
echo " [*] openvas-libraries-9.9.1 downloaded "
wget http://wald.intevation.org/frs/download.php/2423/openvas-scanner-5.1.1.tar.gz ${NOCERT}
echo " [*] openvas-scanner-5.1.1 downloaded "
wget http://wald.intevation.org/frs/download.php/2426/openvas-manager-7.0.2.tar.gz ${NOCERT}
echo " [*] openvas-manager-7.0.2 downloaded "
wget http://wald.intevation.org/frs/download.php/2429/greenbone-security-assistant-7.0.2.tar.gz ${NOCERT}
echo " [*] greenbone-security-assistent-7.0.2 downloaded "
wget http://wald.intevation.org/frs/download.php/2397/openvas-cli-1.4.5.tar.gz ${NOCERT}
echo " [*] openvas-cli-1.4.5 downloaded "
wget https://github.com/greenbone/openvas-smb/archive/v1.0.4.tar.gz ${NOCERT}
# use openvas-smb-1.0.4 for compatability. Other version will lead to errors during install becauseof undefined reference to `gnutls_certificate_type_set_priority`
echo " [*] openvas-smb-1.0.4 downloaded "
#wget http://wald.intevation.org/frs/download.php/2401/ospd-1.2.0.tar.gz ${NOCERT}
#wget http://wald.intevation.org/frs/download.php/2405/ospd-debsecan-1.2b1.tar.gz ${NOCERT}
wget https://svn.wald.intevation.org/svn/openvas/branches/tools-attic/openvas-check-setup ${NOCERT}
echo " [*] openvas-check-setup script downloaded "
find . -name \*.gz -exec tar zxvfp {} \;
echo " [*] downloaded files unpacked and folders created"
chmod +x openvas-check-setup
echo " [*] openvas_check_setup is now executable"
rm *.tar.gz
echo " [*] *.tar.gz files removed" 
echo " "

sleep 10

echo " "
echo -e " ${GRE} ---------- BUILDING SOURCES ---------- ${NOC} "
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"
for p in "${_package_list[@]}"
do
    echo " [*] cd into openvas-$p"
    cd ${DIR}/${BASE}$p${HINT}/
    echo " [*] create source folder"
    mkdir source && cd source
    echo " [*] run cmake"
    cmake ..
    echo " [*] run make"
    make
    echo " [*] run make install and cd out of openvas-$p"
    make install && cd ../../
    echo " [*] $p installed"
    echo " "
    sleep 5
done

cd ${DIR}/$GSA${HINT}/
mkdir source && cd source
cmake ..
make
echo " [*] run make install and cd out of openvas-$p"
make install && cd ../../
#cd ../../
echo " [*] $GSA installed"
echo " "

sleep 20

echo " "
echo -e " ${GRE} ---------- CONFIGURATION ---------- ${NOC} "
cp /etc/redis/redis.conf /etc/redis/redis.orig
echo " [*] redis.conf backup complete"
#echo "unixsocket /tmp/redis.sock" >> /etc/redis/redis.conf
sed -i -- 's:# unixsocket /var/run/redis/redis.sock:unixsocket /tmp/redis.sock:g' /etc/redis/redis.conf
echo " [*] redis set to use unixsocket"
sed -i -- 's/# unixsocketperm 700/unixsocketperm 700/g' /etc/redis/redis.conf
#echo "unixsocketperm 700" >> /etc/redis/redis.conf
echo " [*] permissions for unixsocket set"
ln -fs /var/run/redis/redis.sock /tmp/redis.sock
service redis-server restart
openvas-manage-certs -a
echo " [*] certificates ready"
ldconfig
echo " [*] ldconfig done"
echo " "

sleep 5

echo " "
echo -e " ${GRE} ---------- UPDATING DATA ---------- ${NOC} "
ldconfig
/usr/local/sbin/greenbone-nvt-sync
sleep 5

[ ! -f /usr/local/lib/libopenvas_omp.so.9 ] && sudo ln -fs /usr/local/lib/libopenvas_omp.so.9.0.1 /usr/local/lib/libopenvas_omp.so.9
[ ! -f /usr/local/lib/libopenvas_nasl.so.9 ] && sudo ln -fs /usr/local/lib/libopenvas_nasl.so.9.0.1 /usr/local/lib/libopenvas_nasl.so.9

echo " [*] nvt sync done"
/usr/local/sbin/greenbone-scapdata-sync
sleep 5
echo " [*] scapdata sync done"
ldconfig
/usr/local/sbin/greenbone-certdata-sync
sleep 5
echo " [*] certdata sync done"
echo " "

echo " "
echo -e " \${GRE} ---------- LAUNCHING SCANNER ---------- \${NOC} "
service redis-server restart
sleep 30
sudo ldconfig
sudo /usr/local/sbin/openvassd
echo " [*] openvassd started"

echo " "
echo -e " \${GRE} ---------- REBUILDING NVT ---------- \${NOC} "
sleep 20
sudo ldconfig
sudo /usr/local/sbin/openvasmd --rebuild --progress
sleep 10
echo -e " \${GRE} ---------- LAUNCHING MANAGER ---------- \${NOC} "
sudo ldconfig
sudo /usr/local/sbin/openvasmd

echo " "
echo -e " \${GRE} ---------- LAUNCHING UI ---------- \${NOC} "
sleep 30
sudo ldconfig
sudo /usr/local/sbin/gsad --http-only
echo " [*] gsad started with --http-only"
echo " "


echo " [*] OpenVAS ready for use!"
echo " "
echo "Next Step: Create a user"
echo "\${GRE} [*] Whats the name of the new user? \${NOC}"
read name
openvasmd --create-user=$name --role=Admin
echo " [*] New user with role \'Admin\' created "
echo " "
echo "\${GRE} Set new password for $name: \${NOC}"
read pw
openvasmd --user=$name --new-password=$pw
echo " [*] New password set "
echo " "
echo "[----------]  HAPPY SCANNING  [----------]"
