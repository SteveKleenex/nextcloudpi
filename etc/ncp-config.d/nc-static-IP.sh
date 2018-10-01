#!/bin/bash

# Enable static IP or DHCP for Raspbian
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at: https://ownyourbits.com
#

ACTIVE_=no
IP_=192.168.1.130

DESCRIPTION="Set up a static IP address (on), or DHCP (off)"

configure() 
{
  local GW="$( ip r | grep "default via"   | awk '{ print $3 }' )"
  local DNS="$( grep nameserver /etc/resolv.conf | head -1 | awk '{ print $2 }' )"
  [[ "$DNS" == "" ]] && DNS="$GW"
  local IFACE="$( ip r | grep "default via" | awk '{ print $5 }' | head -1 )"
  [[ "$IFACE" == "" ]] && { echo "Couldn't find default interface"; exit 1; }

  ## DHCPCD
  [[ -f /etc/dhcpcd.conf ]] && {
    # delete NCP config
    grep -q "^# NextCloudPi autogenerated" /etc/dhcpcd.conf && \
      sed -i '/^# NextCloudPi autogenerated/,+6d' /etc/dhcpcd.conf

    [[ $ACTIVE_ != "yes" ]] && {
      systemctl restart dhcpcd
      echo "DHCP enabled"
      return
    }

    cat >> /etc/dhcpcd.conf <<EOF
# NextCloudPi autogenerated
# don't modify! better use ncp-config
interface $IFACE
static ip_address=$IP_/24
static routers=$GW
static domain_name_servers=$DNS

# Local loopback
auto lo
iface lo inet loopback
EOF

    systemctl restart dhcpcd
  } || {
    ## NETWORK MANAGER

    cp -n /etc/network/interfaces /etc/network/interfaces-ncp-backup-orig

    [[ $ACTIVE_ != "yes" ]] && {
      cat > /etc/network/interfaces <<EOF
# Wired adapter #1
allow-hotplug $IFACE
no-auto-down $IFACE
auto $IFACE
iface $IFACE inet dhcp

# Local loopback
auto lo
iface lo inet loopback
EOF
      systemctl restart NetworkManager
      echo "DHCP enabled"
      return
    }

    cat > /etc/network/interfaces <<EOF
# ncp-config generated
source /etc/network/interfaces.d/*

# Local loopback
auto lo
iface lo inet loopback

# Interface $IFACE
auto $IFACE
allow-hotplug $IFACE
iface $IFACE inet static
    address $IP_
    netmask 255.255.255.0
    gateway $GW
    dns-nameservers $DNS 8.8.8.8
EOF
    systemctl restart networking
  }
 
  sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value="$IP_"
  sudo -u www-data php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value=https://"$IP_"/
  echo "Static IP set to $IP_"
}

install() { :; }

# License
#
# This script is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA  02111-1307  USA

