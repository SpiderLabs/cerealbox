=header
    cb.pl - cerealbox controller
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
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

#!/usr/bin/env perl

use strict; 
use warnings;
use Net::Pcap;
use NetPacket::Ethernet qw(:strip);
use NetPacket::IP qw(:strip);
use NetPacket::TCP;
use NetPacket::UDP;
use Geo::IP;
use Device::SerialPort;
$| = 1;

my $usage = "cb.pl (net_device) (src_ipaddr) (serial_device) [dns]\n";

unless ($ARGV[2]) {
	print $usage;
	my ($err, %devinfo);
	my @devs = Net::Pcap::findalldevs(\$err, \%devinfo);
	if ($devs[0]) {
		print "\n";
		print "Interfaces found:\n\n";
		for my $d (@devs) {
		    print "$d - $devinfo{$d}\n";
		}
		print "\n";
	    exit;
	}
	else {
		print "No interfaces found. Ensure that current user has admin/root priveleges.\n";
		exit;
	}
}

my $dev = $ARGV[0];
my $myip = $ARGV[1];
my $ser = $ARGV[2];
my $mode = $ARGV[3];

# Get net info for device to create filter
my ($address, $netmask, $err);
if (Net::Pcap::lookupnet($dev, \$address, \$netmask, \$err)) {
    die 'Unable to look up device information for ', $dev, ' - ', $err;
}

my $port = Device::SerialPort->new($ser) || die "Unable to open serial device $ser\n";
$port->baudrate(9600);
$port->handshake("none");
$port->databits(8);
$port->stopbits(1);

my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);

# Open device
# Max IPv4/TCP = 90
# Max IPv4/UDP = 66
my $snaplen = 90;
my $promisc = 0;
my $to_ms = 15;
my $pcap = Net::Pcap::open_live($dev, $snaplen, $promisc, $to_ms, \$err);
unless ($pcap) {
    die "Error opening live: $err\n";
}

my $filter_str;
# meter mode should include DNS, but it tends to spam session mode 
if ($mode) {
    if ($mode eq 'dns') {
        $filter_str = "(tcp or udp) and host $myip";
    }
}
else {
    $filter_str = "(tcp or udp) and host $myip and not port 53";
}

my $filter;
Net::Pcap::compile($pcap, \$filter, $filter_str, 1, $netmask) &&
    die 'Unable to compile packet capture filter';
Net::Pcap::setfilter($pcap, $filter) &&
    die 'Unable to set packet capture filter';

#Not setting non-block because of Win32 and Snow Leopard issues

my %db;
my %udp_db;

sub ip2hex {
	my ($in) = @_;
	my @ip = split(/\./, $in);
	my $hex = sprintf("%02x%02x%02x%02x", $ip[0], $ip[1], $ip[2], $ip[3]);
	return $hex;
}

my $numclose = 0;
my $numopen = 0;

sub s_open {
    my ($sport,$dmac,$dip,$dport) = @_;
    my $cc = $gi->country_code_by_addr($dip) || "LL";
    ++$numopen;
    event(1, $dmac, $dip, $dport, $cc);
    $db{$sport}->{cc} = $cc;
    $db{$sport}->{dmac} = $dmac;
    $db{$sport}->{dip} = $dip;
    $db{$sport}->{dport} = $dport;
    $db{$sport}->{close} = 0;
    $db{$sport}->{time} = time();
}

sub s_close {
    my ($sport) = @_;
    if ($db{$sport}) {
        if ($db{$sport}->{close} == 0) {
            ++$numclose; 
            event (2, $db{$sport}->{dmac}, $db{$sport}->{dip}, $db{$sport}->{dport}, $db{$sport}->{cc});
            $db{$sport}->{close} = 1;
        }
    }
}

sub u_open {
    my ($sport,$dmac,$dip,$dport) = @_;
    my $cc = $gi->country_code_by_addr($dip) || "LL";
    ++$numopen;
    event(1, $dmac, $dip, $dport, $cc);
    $udp_db{$sport}->{cc} = $cc;
    $udp_db{$sport}->{dmac} = $dmac;
    $udp_db{$sport}->{dip} = $dip;
    $udp_db{$sport}->{dport} = $dport;
    $udp_db{$sport}->{time} = time();
}

sub u_close {
    my ($sport) = @_;
    if ($udp_db{$sport}) {
        ++$numclose; 
        event (2, $udp_db{$sport}->{dmac}, $udp_db{$sport}->{dip}, $udp_db{$sport}->{dport}, $udp_db{$sport}->{cc});
        delete $udp_db{$sport};
    }
}


my $pkts = 0;
my $lasttime = 0;

sub process_packet {
    my ($d,$header,$pkt) = @_;
    ++$pkts;
    my $eth = NetPacket::Ethernet->decode($pkt);
    my $ip = NetPacket::IP->decode($eth->{data});
    # UDP
    if ($ip->{proto} == 17) {
        my $udp = NetPacket::UDP->decode($ip->{data});
        my ($dmac, $dip, $dport, $sport);
        if ($ip->{dest_ip} eq $myip) {
            ($dmac, $dip, $dport, $sport) = ($eth->{src_mac}, $ip->{src_ip}, $udp->{src_port}, $udp->{dest_port});
        }
        elsif ($ip->{src_ip} eq $myip) {
            ($dmac, $dip, $dport, $sport) = ($eth->{dest_mac}, $ip->{dest_ip}, $udp->{dest_port}, $udp->{src_port});
        }
        else {
            return;
        }
        
        if ($udp_db{$sport}) {
            $udp_db{$sport}->{time} = time();
        }
        else {
            u_open($sport,$dmac,$dip,$dport);
        } 
    }
        
    # TCP
    if ($ip->{proto} == 6) {
        my $tcp = NetPacket::TCP->decode($ip->{data});
    
        my ($dmac, $dip, $dport, $sport);
    
        if ($ip->{dest_ip} eq $myip) {
            ($dmac, $dip, $dport, $sport) = ($eth->{src_mac}, $ip->{src_ip}, $tcp->{src_port}, $tcp->{dest_port});
        }
        elsif ($ip->{src_ip} eq $myip) {
            ($dmac, $dip, $dport, $sport) = ($eth->{dest_mac}, $ip->{dest_ip}, $tcp->{dest_port}, $tcp->{src_port});
        }
        else {
            return;
        }
    
        #if ((($tcp->{flags} & SYN) == SYN) and (($tcp->{flags} & ACK) != ACK)) {
            # Will handle these differently, they are intent to connect but not actual connection
        #}
    
        # Kill connection if RST or FIN detected
        # SHOULD BE ELSIF, but SYN is interesting, look at how to use SYN
        if ((($tcp->{flags} & FIN) == FIN) or (($tcp->{flags} & RST) == RST)) {
            s_close($sport);
        }
    
        # After we see RST/FIN on a source port, it can only be reopened using SYN+ACK
    
        elsif ((($tcp->{flags} & SYN) == SYN) and (($tcp->{flags} & ACK) == ACK)) {
            if ($db{$sport}) {
                if ($db{$sport}->{close} == 1) {
                    s_open($sport,$dmac,$dip,$dport);
                }
            }
            else {
                s_open($sport,$dmac,$dip,$dport);
            }
        }
    

        # Otherwise see if connection exists and create if it doesn't
        # Only do this if sport hasn't been used before
    
        else {
            # If connection is open, update time
            if ($db{$sport}) {
                if ($db{$sport}->{close} == 0) {
                    $db{$sport}->{time} = time();
                }
            }
            else {
                s_open($sport,$dmac,$dip,$dport);
            }
        }
    }
    
    # Check list every x seconds for timed out connections
    my $now = time();
    if ($now - $lasttime > 10) {
        print "Open connections:\n";
        print "TCP\n";
        my $x;
        foreach $x (keys(%db)) {
            if ($db{$x}->{close} == 0) {
                if ($now - $db{$x}->{time} > 60) {
                    print "timeout " . $db{$x}->{dip} . "\n";
                    s_close($x);
                }
                else {
                    my $txt = uc($db{$x}->{dmac}) . "," . $db{$x}->{dip} . "," . $db{$x}->{dport} . "," . $db{$x}->{cc};
                    print "$txt\n";
                }
            }
        }
        print "\nUDP\n";
        foreach $x (keys(%udp_db)) {
            if ($now - $udp_db{$x}->{time} > 20) {
                #print "timeout " . $udp_db{$x}->{dip} . "\n";
                u_close($x);
            }
            else {
                my $txt = uc($udp_db{$x}->{dmac}) . "," . $udp_db{$x}->{dip} . "," . $udp_db{$x}->{dport} . "," . $udp_db{$x}->{cc};
                print "$txt\n";
            }
        }
        $lasttime = time();
    }
}

sub event {
    my ($code,$dmac,$dip,$dport,$cc) = @_;
    my $txt = "$code," . uc($dmac) . "," . uc(ip2hex($dip)) . "," . sprintf("%04X", $dport) . ",$cc";
    $port->write("\n$txt\n");
    print "$txt\n";
    my $curr = $numopen - $numclose;
    print "close:$numclose open:$numopen current:$curr\n";
}



# Give it a few secs to "warm up", otherwise first serial cmds get ignored
sleep 3;

# Init port
$port->write(" \n");

# Start loop
Net::Pcap::pcap_loop($pcap, -1, \&process_packet, "pcap");

    
