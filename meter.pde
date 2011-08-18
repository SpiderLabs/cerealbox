/*
cerealbox 
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
*/

#include <Colorduino.h>
#define CMD_BUFFER 32
#define WEB 0
#define DNS 1
#define REMOTE 2
#define MAIL 3
#define FILE 4
#define UNDERTEN 5
#define OVERTEN 6
#define LOCAL 7
#define smillis() ((long)millis())

int incomingByte;      // a variable to read incoming serial data into
//int x = 1;
long timeout=smillis()+100;
int colors[8][3];
int buf;
int i=0;
char cmd[CMD_BUFFER];
int meter[8] = {1,1,1,1,1,1,1,1};

void flush_buffer() {
  //Serial.write("flush\n");
  for (int x = 0; x < CMD_BUFFER; x++) {
    cmd[x] = 0;
  }
  i=0;
}

int tohex(int a) {
  if (a > 47 && a < 58) {
    return a - 48;
  }
  else if (a > 64 && a < 71) {
    return a - 55;
  }
}

void setup() {
  // initialize serial communication:
  Serial.begin(9600);
  Colorduino.Init(); // initialize the board
  
  // compensate for relative intensity differences in R/G/B brightness
  // array of 6-bit base values for RGB (0~63)
  // whiteBalVal[0]=red
  // whiteBalVal[1]=green
  // whiteBalVal[2]=blue
  unsigned char whiteBalVal[3] = {36,63,63}; // for LEDSEE 6x6cm round matrix
  Colorduino.SetWhiteBal(whiteBalVal);
  
  //Define colors used by meters
  colors[WEB][0] = 55;
  colors[WEB][1] = 0;
  colors[WEB][2] = 0;
  
  colors[DNS][0] = 0;
  colors[DNS][1] = 0;
  colors[DNS][2] = 55;
  
  colors[REMOTE][0] = 0;
  colors[REMOTE][1] = 55;
  colors[REMOTE][2] = 0;
  
  colors[MAIL][0] = 55;
  colors[MAIL][1] = 55;
  colors[MAIL][2] = 0;
  
  colors[FILE][0] = 55;
  colors[FILE][1] = 00;
  colors[FILE][2] = 55;
  
  colors[OVERTEN][0] = 00;
  colors[OVERTEN][1] = 55;
  colors[OVERTEN][2] = 55;
  
  colors[UNDERTEN][0] = 200;
  colors[UNDERTEN][1] = 50;
  colors[UNDERTEN][2] = 00;
  
  colors[LOCAL][0] = 255;
  colors[LOCAL][1] = 255;
  colors[LOCAL][2] = 255;
  
}

//Julian Skidmore's rollover-proof timer
boolean after(long timeout) {
    return smillis()-timeout>0;
}

void loop() {
  if (after(timeout)) {
    //blank screen
    for (int z=0; z < 64; z++) {
      Colorduino.SetPixel(z,0,0,0,0);
    }
    for (int m=0; m < 8; m++) {
      for (int x=7; (8 - x) != meter[m]+1; x--) {
        Colorduino.SetPixel(x,m,colors[m][0],colors[m][1],colors[m][2]);
      }
      if (meter[m] > 2) {
        meter[m] = meter[m] - 2;
      }
      else if (meter[m] == 2) {
        meter[m]--;
      }
    }
    
    Colorduino.FlipPage();
    
    
  timeout=(long)millis()+100;
  }

    
  
  if (Serial.available() > 0) {
    // read the oldest byte in the serial buffer:
    buf = Serial.read();
    
    if (buf == 10 || buf == 13) {
      if (i == 31) {
        // Add null
        cmd[i+1] = 0;
        
        //Process command
        
        //Increment cmd counter for rate comparison
        //Serial.write("increment numcmd\n");
        
        //"1" - add command
        if (cmd[0] == 49) {
          //Check validity of data
          boolean invalid = false;
          
          for (int x=1; x < 28; x++) {
            if ((cmd[x] >= 48 && cmd[x] <= 57) || (cmd[x] >= 65 && cmd[x] <= 90) || (cmd[x] == 44)) {}
            else invalid = true;
          }
          
          if (invalid == true) {
            flush_buffer();
          }
          
          else { 
            
            // 'Add' command
            if (cmd[0] == 49) {
              
              //pos 7-8 are port
              unsigned int port = (tohex(cmd[24])*pow(16,3)) + (tohex(cmd[25])*pow(16,2)) + (tohex(cmd[26])*pow(16,1)) + (tohex(cmd[27]));
              
              // Define mappings to meters
              if ((port == 80) || (port == 443) || (port == 8080)) {
                meter[WEB] = 8;
                //Serial.write("web\n");
              }
              else if (port == 53) {
                meter[DNS] = 8;
                //Serial.write("dns\n");
              }
              else if ((port == 22) || (port == 23) || (port == 3389)) {
                meter[REMOTE] = 8;
              }
              else if ((port == 110) || (port == 25) || (port == 143) || (port == 389) || (port == 465) || (port == 993) || (port == 995) ) {
                meter[MAIL] = 8;
              }
              else if ((port == 21) || (port == 88) || (port == 135) || (port == 137) || (port == 138) || (port == 139) || (port == 427) || (port == 445) || (port == 515) || (port == 548) || (port == 631) || (port == 9100) ) {
                meter[FILE] = 8;
              }
              else if (port < 10000) {
                meter[UNDERTEN] = 8;
              }
              else if (port >= 10000) {
                meter[OVERTEN] = 8;
              }
              
              // Do local in addition to ports
              if ((cmd[29] == 76) && (cmd[30] == 76)) {
                meter[LOCAL] = 8;
              }
              
              flush_buffer();
            }
          }
        }
        else {
          flush_buffer();
        }
      }
      else {
        flush_buffer();
      }  
    }
    //Otherwise we're still reading data
    //A-Z, 0-9, and comma
    else if ((buf >= 48 && buf <= 57) || (buf >= 65 && buf <= 90) || (buf == 44)) {
      cmd[i] = buf;
      i++;
    }
    else {
      flush_buffer();
    }
  }
}
