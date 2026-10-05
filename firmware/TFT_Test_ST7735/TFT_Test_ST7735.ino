/*
 * TEST MÀN TFT 0.96" ST7735 — giảm NHIỄU (HSPI)
 *
 * Thư viện: Adafruit GFX + Adafruit ST7735 and ST7789
 *
 * Nối dây:
 *   GND->GND  VCC->3.3V
 *   SCL->22   SDA->21   RES->17   DC->16
 *   CS -> D5 (GPIO5)    BLK-> D15 (GPIO15)
 *
 * Nếu còn nhiễu: hạ TFT_SPI_HZ, đổi TFT_INIT_MODE (0/1/2), TFT_INVERT (0/1)
 */

#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>

#define TFT_INIT_MODE  1   // thử: 1 -> 0 -> 2
#define TFT_INVERT     1   // thử: 1 rồi 0

#define TFT_SCLK  22
#define TFT_MOSI  21
#define TFT_MISO  -1
#define TFT_RST   17
#define TFT_DC    16
#define TFT_CS     5
#define TFT_BLK   15

#define TFT_SPI_HZ  1000000UL

SPIClass spiTFT = SPIClass(HSPI);
Adafruit_ST7735 tft = Adafruit_ST7735(&spiTFT, TFT_CS, TFT_DC, TFT_RST);

void drawCleanScreen(uint16_t n) {
  tft.fillScreen(ST77XX_BLACK);
  tft.drawRect(0, 0, 160, 80, ST77XX_WHITE);

  tft.setTextWrap(false);
  tft.setTextSize(2);
  tft.setTextColor(ST77XX_YELLOW);
  tft.setCursor(10, 14);
  tft.print("TFT OK");

  tft.setTextSize(1);
  tft.setTextColor(ST77XX_CYAN);
  tft.setCursor(10, 40);
  tft.print("HSPI 1MHz");

  char buf[24];
  snprintf(buf, sizeof(buf), "CS5 BLK15 n=%u", n);
  tft.setTextColor(ST77XX_WHITE);
  tft.setCursor(10, 56);
  tft.print(buf);
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("======== TFT ANTI-NOISE (HSPI) ========");
  Serial.println("SCL=22 MOSI=21 RES=17 DC=16 CS=5 BLK=15");

  pinMode(TFT_BLK, OUTPUT);
  digitalWrite(TFT_BLK, HIGH);

  spiTFT.begin(TFT_SCLK, TFT_MISO, TFT_MOSI, TFT_CS);
  delay(20);

#if TFT_INIT_MODE == 1
  tft.initR(INITR_MINI160x80_PLUGIN);
  Serial.println("[TFT] INITR_MINI160x80_PLUGIN");
#elif TFT_INIT_MODE == 2
  tft.initR(INITR_BLACKTAB);
  Serial.println("[TFT] INITR_BLACKTAB");
#else
  tft.initR(INITR_MINI160x80);
  Serial.println("[TFT] INITR_MINI160x80");
#endif

  tft.setSPISpeed(TFT_SPI_HZ);
  tft.setRotation(1);

#if TFT_INVERT
  tft.invertDisplay(true);
#else
  tft.invertDisplay(false);
#endif

  tft.fillScreen(ST77XX_RED);   delay(250);
  tft.fillScreen(ST77XX_GREEN); delay(250);
  tft.fillScreen(ST77XX_BLUE);  delay(250);

  drawCleanScreen(0);
  Serial.printf("[TFT] SPI=%lu Hz\n", (unsigned long)TFT_SPI_HZ);
}

void loop() {
  static uint32_t t0 = 0;
  static uint16_t n = 0;

  if (millis() - t0 < 3000) return;
  t0 = millis();
  n++;
  drawCleanScreen(n);
}
