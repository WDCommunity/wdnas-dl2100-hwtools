#!/usr/bin/env bash

################################################################################
## 
## LCD menu action
## Note that it executes both on button press as on release
## 
## Copyright (c) 2018 Stefaan Ghysels <stefaang@gmail.com>
## 
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
## 
################################################################################


function get_ip {
	ip route get 1 | awk '{print $NF;exit}'
}

function get_disk_usage {
	df $1 -h --output=avail,pcent | sed 1d | awk '{print $1, "free", $2, "used"}'
}

function get_temperature {
	wdhwc temperature | sed 's#: #\\n           #'
}

function get_fan_speed {
	wdhwc fan | sed 's#: #\\n#'
}


# button press event triggers both on press as on release
# so we only act on the even numbers
#
# TODO: add long-press example

case "$(( ${1#-} % 10 ))" in
	0)
		wdhwc lcd -t "Dim the lights"
		wdhwc lcd -s 0
		;;
	2)
		wdhwc lcd -s 240
		wdhwc lcd -t "IP address\n$(get_ip)"
		;;
	4)
		root_usage=$(get_disk_usage /)
		wdhwc lcd -t "Root Disk Usage\n${root_usage}"
		;;
	6)
		temperature=$(get_temperature)
		wdhwc lcd -t "$temperature"
		;;
	8)	
		fan_speed=$(get_fan_speed)
		wdhwc lcd -t "$fan_speed"
		;;
	*)
		# do nothing
		;;
esac

