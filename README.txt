cerealbox 
Steve Ocepek <socepek@trustwave.com>
http://www.spiderlabs.com

INTRODUCTION
============

cerealbox is an Arduino-based network monitor. 


REQUIREMENTS
============

This code should run on any Arduino board with 2k SRAM equipped with
Colors Shield, or the all-in-one Colorduino board. Both Colorduino and
Colors Shield are available from iTead Studio.

http://iteadstudio.com/

Test/Dev system is: Ardunio Uno, Colors Shield, 8x8 round LED matrix (iTead)


Also included is cb.pl, a sniffer that provides network session data
to the Arduino over USB. Perl requirements for cb.pl include:

Net::Pcap
NetPacket (Ethernet,IP,TCP,UDP)
Geo::IP
Device::SerialPort


USAGE
=====

Arduino
-------

Load cerealbox.pde or meter.pde onto Arduino using the Arduino IDE.

cerealbox.pde displays a dot for each open session, color-coded to the 
Country Code of the remote host.

meter.pde shows types of sessions being established in an "equalizer"
type view.

RED     - Web (80,443,8080)
BLUE    - DNS
GREEN   - Remote protocols (SSH,Telnet,RDP)
YELLOW  - Mail protocols (POP3,SMTP,IMAP,LDAP)
PURPLE  - File protocols (FTP,SMB,AFP,LPR)
ORANGE  - Other ports, under 10000
CYAN    - Other ports, over or equal to 10000
WHITE   - Local hosts

Perl
----

This program requires root privileges to sniff packets.

cb.pl (net_device) (src_ipaddr) (serial_device) [dns]

net_device is the network device to listen on, ex. eth0
- Running cb.pl without args will show all available interfaces

src_ipaddr is the source IP address of the host to be monitored.
- In normal cases, this will be the host's own IP address
- Could be used to sniff another host's traffic in cases where
  traffic is visible (i.e. MITM, ethernet tap, wireless)

serial_device is the USB serial device that the Arduino is using, ex:
- /dev/ttyUSB0 on Linux
  Or whichever was assigned to Arduino, use dmesg to find out
- /dev/tty.usbmodem262312 on Mac OS X
  Use ls /dev/tty.usbmodem* to find this

Untested on Windows, not sure whether Device::SerialPort can handle
COM: ports

dns specifies that DNS sessions should be tracked and displayed
- Useful for meter mode, but this traffic tends to fill up session mode
  (cerealbox.pde) very quickly



COPYRIGHT
=========

cerealbox - Arduino-based network monitor
Created by Steve Ocepek
Copyright (C) 2011 Trustwave Holdings, Inc.
 
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>
