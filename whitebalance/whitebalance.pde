#include <Colorduino.h>

void setup()
{
  Colorduino.Init();
  // compensate for relative intensity differences in R/G/B brightness
  // array of 6-bit base values for RGB (0~63)
  // whiteBalVal[0]=red
  // whiteBalVal[1]=green
  // whiteBalVal[2]=blue
  
  // CHANGE THESE VALUES UNTIL YOU GET WHITE ON THE LED MATRIX
  unsigned char whiteBalVal[3] = {36,63,36}; // <-----
  Colorduino.SetWhiteBal(whiteBalVal);
}

void ColorFill(unsigned char R,unsigned char G,unsigned char B)
{
  PixelRGB *p = Colorduino.GetPixel(0,0);
  for (unsigned char y=0;y<ColorduinoScreenWidth;y++) {
    for(unsigned char x=0;x<ColorduinoScreenHeight;x++) {
      p->r = R;
      p->g = G;
      p->b = B;
      p++;
    }
  }
  
  Colorduino.FlipPage();
}


void loop() {
  ColorFill(255,255,255);
}
