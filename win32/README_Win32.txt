This directory contains a Win32-compatible version of cb.pl and an executable
version of the program. The code was tested with ActiveState 5.12.4; the
executable file was created using PAR packager. The executable has been tested
on Windows 7 with latest service packs as of 9/14/11.

You will need to download the latest GeoIP database file from:

http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz

Once downloaded, decompress the database using WinZip, IZArc, or another program
that supports gzip. Put the resulting file into the same directory as the perl
script or executable and run from the command line.

On Windows, the network device names will be very lengthy and pretty much
require copy/paste. Run cb without arguments to get a list of available network
devices. The serial port will be something similar to "COM4:" - find out which
COM port the Arduino is using by looking inside Device Manager.
