#!/usr/bin/env sh
# TL;DR docker bypasses ufw firewall, so any rules you will apply for 80, 443
# ports simply won't work and they will be seen by the world
# See this to learn more:
# https://www.mkubaczyk.com/2017/09/05/force-docker-not-bypass-ufw-rules-ubuntu-16-04/

# Docker shouldn't update iptables
sudo sh -c 'cat > /etc/docker/daemon.json <<EOF
{"iptables": false}
EOF'

# Set DEFAULT_FORWARD_POLICY to ACCEPT
sudo sed -i -e 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw

# Create a startup script to update iptables by means of cron job because they
# will be reset on reboot
mkdir -p "${HOME}/.scripts"
cat >> "${HOME}/.scripts/startup.sh" <<EOF
#/usr/bin/env sh
# Update iptables rules with a bridge IP to be able to reach the world from
# Docker containers
sleep 5 # bodge to get bridge IP address because Docker takes some time to start up
BRIDGE_IP="$(ip ro | grep br- | awk '{print $1}')"
/sbin/iptables -t nat -A POSTROUTING ! -o docker0 -s "${BRIDGE_IP}" -j MASQUERADE
EOF
chmod +x "${HOME}/.scripts/startup.sh"

# Add cron job for root user because we don't want to enter password for this :)
sudo -u root sh -c '(crontab -l 2>/dev/null; echo "@reboot /bin/sh ${HOME}/.scripts/startup.sh") | crontab -'

# Restart docker and ufw services
sudo systemctl restart ufw docker
