/*
 * ╔══════════════════════════════════════════════════════════════╗
 * ║     THỦY CANH IoT — STEM (ESP32) + MQTT APP (AloT WSS)      ║
 * ╠══════════════════════════════════════════════════════════════╣
 * ║  ✅ DHT22 + LDR + pH + HC-SR04 (+ TDS tùy chọn)             ║
 * ║  ✅ TFT IPS 0.96" 80x160 ST7735 SPI + Relay bơm / đèn       ║
 * ║  ✅ Mực nước: 11cm=ĐẦY / 18cm=THẤP + Kalman 1D HC-SR04   ║
 * ║  ✅ WiFi Portal AP tĩnh 192.168.4.1 (lưu tối đa 5 mạng)    ║
 * ║  ✅ MQTT qua WebSockets SSL (WSS Port 443 Cloudflare)       ║
 * ║  ✅ Topic kiểu AloT: tele/<device>/status  {"value":...}    ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 * THƯ VIỆN CẦN CÓ:
 * 1. WebSockets by Markus Sattler
 * 2. MQTTPubSubClient by Hideaki Tai
 * 3. DHT sensor library (Adafruit) + Adafruit Unified Sensor
 * 4. Adafruit GFX + Adafruit ST7735 and ST7789 Library
 *
 * APP: mở folder thuycanh/ — chipId = 790 (KHÔNG dùng 789 của máy Ngưng Tụ)
 *
 * Sơ đồ chân:
 *   DHT22     -> GPIO 4
 *   LDR       -> GPIO 34 (analog)
 *   pH        -> GPIO 35 (analog)
 *   TDS       -> GPIO 32 (analog, tùy chọn)
 *   HC-SR04   -> TRIG GPIO 12, ECHO GPIO 13
 *
 * TFT IPS 0.96" 80x160 (SPI — chân ghi SCL/SDA nhưng là SPI, KHÔNG phải I2C):
 *   GND  -> GND
 *   VCC  -> 3.3V
 *   SCL  -> GPIO 22   (SPI SCK)  << giữ như đã hàn OLED cũ
 *   SDA  -> GPIO 21   (SPI MOSI) << giữ như đã hàn OLED cũ
 *   RES  -> GPIO 17
 *   DC   -> GPIO 18   << BẮT BUỘC GPIO (không nối GND)
 *   CS   -> GND       << nối GND cứng (không dùng GPIO ESP32)
 *   BLK  -> 3.3V      << nối 3.3V cứng (đèn nền luôn sáng, không dùng GPIO)
 *   (Không dùng GPIO cho CS / BLK)
 *
 * RELAY 2 KÊNH (điều khiển bơm + đèn):
 *   IN1 (kênh 1 - BƠM)  -> GPIO 26
 *   IN2 (kênh 2 - ĐÈN)  -> GPIO 27
 *   VCC module          -> 5V (hoặc 3.3V tùy module)
 *   GND                 -> GND chung ESP32
 *   COM/NO mỗi kênh cấp nguồn riêng cho bơm 5V / đèn trồng
 *   Đèn: chế độ AUTO theo LDR (tối -> bật, sáng -> tắt)
 *
 * LƯU Ý ĐIỆN ÁP:
 *   - ECHO HC-SR04 = 5V -> cầu phân áp (1k + 2k) trước GPIO 13
 *   - Module pH có thể tới 5V -> cầu phân áp + chỉnh PH_DIVIDER
 */

#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>
#include <WebSocketsClient.h>
#include <MQTTPubSubClient.h>
#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <DHT.h>
#include <esp_system.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// Một số module IPS cần invert / init khác — thử lần lượt nếu màu/offset lệch
// 0 = INITR_MINI160x80  |  1 = INITR_MINI160x80_PLUGIN  |  2 = INITR_BLACKTAB
#define TFT_INIT_MODE   0
#define TFT_INVERT      1   // IPS hay bị âm màu → để 1; nếu màu đúng thì đổi 0

// ─────────────────────────────────────────────────────────────
//  DEBUG Serial (115200) — đặt 0 để tắt log chi tiết
// ─────────────────────────────────────────────────────────────
#define DEBUG_SERIAL  1

#if DEBUG_SERIAL
  #define DBG(...)       Serial.printf(__VA_ARGS__)
  #define DBG_LN(msg)    Serial.println(msg)
#else
  #define DBG(...)       do {} while (0)
  #define DBG_LN(msg)    do {} while (0)
#endif

// ─────────────────────────────────────────────────────────────
//  CHÂN PHẦN CỨNG THỦY CANH
// ─────────────────────────────────────────────────────────────
#define PIN_DHT       4
#define PIN_LDR       34
#define PIN_PH        35
#define PIN_TDS       32
#define PIN_TRIG      12
#define PIN_ECHO      13
// Relay 2 kênh: IN1 = bơm, IN2 = đèn
#define PIN_PUMP      26   // Relay CH1 -> bơm tuần hoàn
#define PIN_LIGHT     27   // Relay CH2 -> đèn trồng
#define PIN_BOOT_BTN  0
#define BOOT_HOLD_MS  3000

// TFT ST7735 SPI 80x160 (xoay ngang → 160x80)
// SCL/SDA giữ GPIO 22/21 như đã hàn trước (bit-bang SPI)
#define TFT_SCLK      22   // SCL trên module
#define TFT_MOSI      21   // SDA trên module (MOSI)
#define TFT_RST       17   // RES
#define TFT_DC        18   // bắt buộc GPIO
#define TFT_CS        -1   // CS hàn sang GND — không chiếm GPIO
// BLK: hàn sang 3.3V (luôn sáng) — không định nghĩa GPIO
#define TFT_W        160
#define TFT_H         80

// ─────────────────────────────────────────────────────────────
//  WIFI PORTAL
// ─────────────────────────────────────────────────────────────
#define AP_SSID       "ThuyCanh"
#define AP_PASSWORD   ""
IPAddress apIP(192, 168, 4, 1);
const byte DNS_PORT = 53;

// ─────────────────────────────────────────────────────────────
//  MQTT (cùng broker AloT — KHÁC chipId với máy Ngưng Tụ 789)
// ─────────────────────────────────────────────────────────────
#define MQTT_HOST     "mqtt.duynguyen.io.vn"
#define MQTT_PORT     443
#define MQTT_PATH     "/mqtt"
#define CHIP_ID       "790"

#define DEV_TEMP      "790_temp"
#define DEV_HUMI      "790_humi"
#define DEV_PH        "790_ph"
#define DEV_TDS       "790_tds"
#define DEV_WATER     "790_water"
#define DEV_DIST      "790_dist"       // khoảng cách HC-SR04 (cm)
#define DEV_WATER_AL  "790_water_alert" // FULL / LOW / OK
#define DEV_LIGHT     "790_light"
#define DEV_PUMP      "790_pump"
#define DEV_LAMP      "790_lamp"
#define DEV_STATUS    "790_status"
#define DEV_POWER     "790_power"

#define EEPROM_SIZE   512
#define MAX_WIFI      5
#define TELEMETRY_MS  2000
#define HEARTBEAT_MS  30000
#define RECONNECT_MS  10000
#define READ_MS       2000

// Relay 2 kênh: đa số module kích mức THẤP (LOW = bật relay)
// Nếu module của bạn kích mức CAO (HIGH = bật) thì đổi thành true
const bool RELAY_ACTIVE_HIGH = false;
#define ENABLE_TDS    false

// Bể nước: khoảng cách cảm biến → mặt nước (cm)
// 11 cm = đầy  |  18 cm = sắp hết (cần bơm nước từ ngoài vào)
const float DIST_FULL_CM  = 11.0f;
const float DIST_EMPTY_CM = 18.0f;
const float DIST_HYST_CM  = 0.6f;
const float DIST_MIN_CM   = 2.0f;
const float DIST_MAX_CM   = 40.0f;

// HC-SR04 + Kalman 1D: chinh xac / toc do / RAM
// 3 mau + median (~40ms); state Kalman ~9 byte, khong malloc
const uint8_t  DIST_BURST_N      = 3;
const uint16_t DIST_BURST_GAP_MS = 12;
const uint32_t ECHO_TIMEOUT_US   = 12000UL;
const float KF_Q = 0.05f;
const float KF_R = 1.0f;
const float KF_OUTLIER_CM = 3.5f;
const float KF_REJECT_CM  = 8.0f;

// Đèn AUTO theo LDR (% ánh sáng). Tối hơn ngưỡng -> bật đèn trồng
const int LIGHT_ON_BELOW_PCT  = 30;  // < 30%  -> bật đèn
const int LIGHT_OFF_ABOVE_PCT = 40;  // > 40%  -> tắt đèn (hysteresis chống nhấp)

// Hiệu chuẩn pH
const float PH_DIVIDER   = 1.0f;
const float PH_VOLT_AT_7 = 2.50f;
const float PH_VOLT_AT_4 = 3.05f;
const float PH_LOW = 5.5f, PH_HIGH = 6.5f;

struct WifiEntry {
  char ssid[33];
  char pass[65];  // WPA tối đa 63 ký tự — trước đây pass[32] dễ cắt mật khẩu → connect fail
};
WifiEntry wifiList[MAX_WIFI];
int wifiCount = 0;

// ─────────────────────────────────────────────────────────────
//  ĐỐI TƯỢNG
// ─────────────────────────────────────────────────────────────
// CS = -1 khi chân CS module đã nối GND
Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS, TFT_DC, TFT_MOSI, TFT_SCLK, TFT_RST);
DHT dht(PIN_DHT, DHT22);
WebServer webServer(80);
DNSServer dnsServer;
WebSocketsClient wsClient;
MQTTPubSubClient mqttClient;

// ─────────────────────────────────────────────────────────────
//  BIẾN THỦY CANH (tiền tố hc* — tránh trùng tên với sketch Ngưng Tụ)
// ─────────────────────────────────────────────────────────────
float hcTemp = NAN, hcHum = NAN, hcPh = NAN, hcTds = 0;
float hcWaterPct = 0;
float hcDistCm = NAN;          // khoảng cách đã lọc (Kalman)
int   hcLightPct = 0;

// Kalman 1D — chỉ ~9 byte RAM tĩnh (không malloc, không buffer lớn)
struct DistKalman1D {
  float x;      // ước lượng (cm)
  float P;      // phương sai
  uint8_t ready;
};
static DistKalman1D distKf = {0.0f, 1.0f, 0};

enum HcMode { HC_AUTO, HC_ON, HC_OFF };
enum WaterAlert { WA_OK, WA_FULL, WA_LOW };
HcMode pumpMode  = HC_AUTO;
HcMode lightMode = HC_AUTO;
WaterAlert waterAlert = WA_OK;
bool pumpOn = false, lightOn = false;
bool systemEnabled = true;
bool tftOK = false;

unsigned long tRead = 0;
const char* statusMsg = "Khoi dong";

// ─────────────────────────────────────────────────────────────
//  BIẾN WIFI / MQTT
// ─────────────────────────────────────────────────────────────
bool portalActive = false;
bool pendingStaConnect = false;
char pendingSsid[33] = {0};
char pendingPass[65] = {0};
unsigned long pendingStaAt = 0;
unsigned long lastTelemetry = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastReconnect = 0;
unsigned long lastMqttRetry = 0;
unsigned long lastTft = 0;
bool wssReady = false;
bool mqttLoggedOk = false;
int wifiRetries = 0;

unsigned long bootPressStart = 0;
bool bootWasPressed = false;

#define DOUBLE_RESET_MAGIC 0x12345678
RTC_DATA_ATTR uint32_t rtcMagic = 0;
bool isDoubleReset = false;

// ─────────────────────────────────────────────────────────────
//  TIỆN ÍCH RELAY / ADC
// ─────────────────────────────────────────────────────────────
void setRelay(uint8_t pin, bool on) {
  // Không spam Serial mỗi chu kỳ — log khi đổi trạng thái ở updateActuators()
  digitalWrite(pin, (on == RELAY_ACTIVE_HIGH) ? HIGH : LOW);
}

// ADC trung binh nhe — 8 mau x 1ms thay vi 20x2ms (nhanh ~5x, du on dinh)
float readAnalogAvg(uint8_t pin, int samples = 8) {
  long sum = 0;
  for (int i = 0; i < samples; i++) {
    sum += analogRead(pin);
    delay(1);
  }
  return sum / (float)samples;
}

float readVoltage(uint8_t pin) {
  return readAnalogAvg(pin) * 3.3f / 4095.0f;
}

// Một lần ping HC-SR04. Trả về cm hoặc -1 nếu lỗi / ngoài dải hợp lệ.
float readDistanceRawCm() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  unsigned long dur = pulseIn(PIN_ECHO, HIGH, ECHO_TIMEOUT_US);
  if (dur == 0) {
    DBG("[HC-SR04] echo timeout\n");
    return -1.0f;
  }

  // cm = us * 0.0343 / 2  (tránh chia float chậm hơn nhân)
  float cm = dur * 0.01715f;
  if (cm < DIST_MIN_CM || cm > DIST_MAX_CM) {
    DBG("[HC-SR04] ngoai dai: %.1f cm (dur=%lu us)\n", cm, dur);
    return -1.0f;
  }
  return cm;
}

// Median 3 số — chống spike tốt hơn average, O(1) RAM
static inline float median3(float a, float b, float c) {
  if (a > b) { float t = a; a = b; b = t; }
  if (b > c) { float t = b; b = c; c = t; }
  if (a > b) { float t = a; a = b; b = t; }
  return b;
}

// Kalman 1D cập nhật tại chỗ — không cấp phát động
float distKalmanUpdate(float z) {
  if (!distKf.ready) {
    distKf.x = z;
    distKf.P = 1.0f;
    distKf.ready = 1;
    return z;
  }

  // Predict (mực nước gần như hằng số giữa 2 lần đọc)
  distKf.P += KF_Q;

  float innov = z - distKf.x;

  // Spike lớn: bỏ mẫu, giữ ước lượng (nhanh + ổn định ngưỡng 11/18)
  if (innov > KF_REJECT_CM || innov < -KF_REJECT_CM) {
    DBG("[KF] REJECT z=%.1f x=%.1f innov=%.1f\n", z, distKf.x, innov);
    return distKf.x;
  }

  // Spike vừa: tăng R (ít tin đo hơn)
  float R = KF_R;
  if (innov > KF_OUTLIER_CM || innov < -KF_OUTLIER_CM) {
    R = KF_R * 6.0f;
    DBG("[KF] soft-outlier innov=%.1f R=%.1f\n", innov, R);
  }

  float K = distKf.P / (distKf.P + R);
  distKf.x += K * innov;
  distKf.P *= (1.0f - K);
  // giữ P trong biên nhỏ để tránh số học lệch lâu dài
  if (distKf.P < 0.01f) distKf.P = 0.01f;
  if (distKf.P > 10.0f) distKf.P = 10.0f;
  DBG("[KF] z=%.1f -> x=%.1f K=%.2f P=%.2f\n", z, distKf.x, K, distKf.P);
  return distKf.x;
}

// Burst 3 mẫu → median → Kalman. ~40ms, RAM stack ~12 byte.
// Trả về -1 nếu không có mẫu hợp lệ.
float readDistanceFilteredCm() {
  float s0 = -1, s1 = -1, s2 = -1;
  uint8_t n = 0;

  for (uint8_t i = 0; i < DIST_BURST_N; i++) {
    float d = readDistanceRawCm();
    if (d > 0.0f) {
      if (n == 0) s0 = d;
      else if (n == 1) s1 = d;
      else s2 = d;
      n++;
    }
    if (i + 1 < DIST_BURST_N) delay(DIST_BURST_GAP_MS);
  }

  if (n == 0) {
    DBG("[HC-SR04] khong co mau hop le (burst=%u)\n", DIST_BURST_N);
    return -1.0f;
  }

  float z;
  if (n == 1) z = s0;
  else if (n == 2) z = 0.5f * (s0 + s1);
  else z = median3(s0, s1, s2);

  DBG("[HC-SR04] n=%u raw=[%.1f %.1f %.1f] z=%.1f\n", n, s0, s1, s2, z);
  return distKalmanUpdate(z);
}

float distanceToPercent(float dCm) {
  float pct = (DIST_EMPTY_CM - dCm) * 100.0f / (DIST_EMPTY_CM - DIST_FULL_CM);
  return constrain(pct, 0.0f, 100.0f);
}

// Cập nhật mức nước + cảnh báo FULL/LOW (có hysteresis)
void updateWaterLevel(float dCm) {
  if (dCm < 0) return;
  WaterAlert prev = waterAlert;
  hcDistCm = dCm;
  hcWaterPct = distanceToPercent(dCm);

  if (waterAlert == WA_FULL) {
    if (dCm >= DIST_FULL_CM + DIST_HYST_CM) waterAlert = WA_OK;
  } else if (waterAlert == WA_LOW) {
    if (dCm <= DIST_EMPTY_CM - DIST_HYST_CM) waterAlert = WA_OK;
  }

  if (waterAlert != WA_FULL && dCm <= DIST_FULL_CM) waterAlert = WA_FULL;
  if (waterAlert != WA_LOW && dCm >= DIST_EMPTY_CM) waterAlert = WA_LOW;

  const char* alName = (waterAlert == WA_FULL) ? "FULL" :
                       (waterAlert == WA_LOW)  ? "LOW"  : "OK";
  DBG("[WATER] dist=%.1fcm pct=%.0f%% alert=%s (full<=%.0f empty>=%.0f)\n",
      hcDistCm, hcWaterPct, alName, DIST_FULL_CM, DIST_EMPTY_CM);
  if (prev != waterAlert) {
    DBG("[WATER] *** ALERT DOI: %d -> %d (%s)\n", (int)prev, (int)waterAlert, alName);
  }
}

float readPH() {
  float v = readVoltage(PIN_PH) * PH_DIVIDER;
  float slope = (7.0f - 4.0f) / (PH_VOLT_AT_7 - PH_VOLT_AT_4);
  float ph = 7.0f + (v - PH_VOLT_AT_7) * slope;
  return constrain(ph, 0.0f, 14.0f);
}

int readLightPercent() {
  // LDR module: thường tối = ADC cao. Nếu bị ngược (đèn luôn sai), đảo map:
  // return constrain(map(raw, 0, 4095, 0, 100), 0, 100);
  int raw = (int)readAnalogAvg(PIN_LDR);
  return constrain(map(raw, 4095, 0, 0, 100), 0, 100);
}

float readTDS(float tempC) {
  float v = readVoltage(PIN_TDS);
  float comp = 1.0f + 0.02f * ((isnan(tempC) ? 25.0f : tempC) - 25.0f);
  float vc = v / comp;
  float tds = (133.42f * vc * vc * vc - 255.86f * vc * vc + 857.39f * vc) * 0.5f;
  return max(0.0f, tds);
}

void updateStatusMsg() {
  if (!systemEnabled) {
    statusMsg = "Tat tu App";
    return;
  }
  // Ưu tiên cảnh báo mực nước (app hiển thị rõ)
  if (waterAlert == WA_LOW) {
    statusMsg = "CANH BAO: NUOC THAP - BOM NGOAI";
    return;
  }
  if (waterAlert == WA_FULL) {
    statusMsg = "CANH BAO: NUOC DAY";
    return;
  }
  if (!isnan(hcPh) && (hcPh < PH_LOW || hcPh > PH_HIGH)) {
    statusMsg = "CANH BAO: pH LECH";
    return;
  }
  statusMsg = "OK";
}

void updateActuators() {
  bool prevPump = pumpOn;
  bool prevLight = lightOn;

  // --- Bơm: AUTO theo cảm biến khoảng cách ---
  // FULL (≤11cm): bơm tuần hoàn ON
  // LOW  (≥18cm): tắt bơm + cảnh báo đổ nước từ ngoài
  // OK (giữa 2 mức): vẫn cho bơm chạy nếu còn nước
  bool wantPump;
  if (!systemEnabled) {
    wantPump = false;
  } else if (pumpMode == HC_ON) {
    wantPump = (waterAlert != WA_LOW);
  } else if (pumpMode == HC_OFF) {
    wantPump = false;
  } else {
    // HC_AUTO
    if (waterAlert == WA_LOW) wantPump = false;
    else if (waterAlert == WA_FULL) wantPump = true;
    else wantPump = true;  // mức trung bình: vẫn tuần hoàn
  }
  pumpOn = wantPump;
  setRelay(PIN_PUMP, pumpOn);   // Relay CH1

  // --- Đèn (Relay CH2): mặc định AUTO theo cảm biến ánh sáng LDR ---
  bool wantLight;
  if (!systemEnabled) {
    wantLight = false;
  } else if (lightMode == HC_ON) {
    wantLight = true;           // ép bật từ app
  } else if (lightMode == HC_OFF) {
    wantLight = false;          // ép tắt từ app
  } else {
    // HC_AUTO: tối -> bật đèn trồng, đủ sáng -> tắt
    if (hcLightPct < LIGHT_ON_BELOW_PCT)       wantLight = true;
    else if (hcLightPct > LIGHT_OFF_ABOVE_PCT) wantLight = false;
    else                                       wantLight = lightOn;  // hysteresis
  }
  lightOn = wantLight;
  setRelay(PIN_LIGHT, lightOn); // Relay CH2

  updateStatusMsg();

  if (prevPump != pumpOn || prevLight != lightOn) {
    DBG("[ACT] *** DOI TRANG THAI  Bom %s->%s (mode=%d)  Den %s->%s (mode=%d LDR=%d%%)  Sys=%d\n",
        prevPump ? "ON" : "OFF", pumpOn ? "ON" : "OFF", (int)pumpMode,
        prevLight ? "ON" : "OFF", lightOn ? "ON" : "OFF", (int)lightMode, hcLightPct,
        (int)systemEnabled);
  }
}

void readSensors() {
  if (millis() - tRead < READ_MS) return;
  tRead = millis();

  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t)) hcTemp = t;
  if (!isnan(h)) hcHum = h;
  else DBG("[DHT] doc loi (nan)\n");

  hcPh = readPH();
  hcLightPct = readLightPercent();

  float d = readDistanceFilteredCm();
  if (d > 0.0f) updateWaterLevel(d);
  else DBG("[WATER] giu gia tri cu dist=%.1f pct=%.0f\n", hcDistCm, hcWaterPct);

  // Doc TDS de hien OLED/MQTT (neu co cam bien)
  if (ENABLE_TDS) hcTds = readTDS(hcTemp);

  DBG("[SENSOR] T=%.1f H=%.0f pH=%.2f TDS=%.0f Light=%d%% Dist=%.1fcm Water=%.0f%% heap=%u\n",
      hcTemp, hcHum, hcPh, hcTds, hcLightPct, hcDistCm, hcWaterPct, ESP.getFreeHeap());

  if (!portalActive) updateActuators();
}

// Vẽ 1 dòng cố định độ rộng + nền đen → không nhấp nháy (không fillScreen)
static void tftLine(int16_t y, uint16_t color, const char* text) {
  tft.setTextColor(color, ST77XX_BLACK);
  tft.setCursor(2, y);
  tft.print(text);
}

void drawOLED() {
  if (!tftOK) return;
  if (millis() - lastTft < 1000) return;  // cập nhật 1s, mượt hơn
  lastTft = millis();

  tft.setTextSize(1);
  tft.setTextWrap(false);

  char line[28];

  if (isnan(hcTemp) || isnan(hcHum))
    snprintf(line, sizeof(line), "Temp: --.-C  Hum: --%%   ");
  else
    snprintf(line, sizeof(line), "Temp:%5.1fC  Hum:%3.0f%%  ", hcTemp, hcHum);
  tftLine(4, ST77XX_CYAN, line);

  if (isnan(hcPh))
    snprintf(line, sizeof(line), "pH: --.--   Light: %3d%%  ", hcLightPct);
  else
    snprintf(line, sizeof(line), "pH: %5.2f   Light: %3d%%  ", hcPh, hcLightPct);
  tftLine(18, ST77XX_GREEN, line);

  if (isnan(hcDistCm))
    snprintf(line, sizeof(line), "Dist: --.-cm  Water: --%% ");
  else
    snprintf(line, sizeof(line), "Dist:%5.1fcm  Water:%3.0f%% ", hcDistCm, hcWaterPct);
  tftLine(32, ST77XX_YELLOW, line);

  if (ENABLE_TDS) {
    if (isnan(hcTds))
      snprintf(line, sizeof(line), "TDS: ---- ppm            ");
    else
      snprintf(line, sizeof(line), "TDS: %4.0f ppm            ", hcTds);
    tftLine(46, ST77XX_WHITE, line);
  } else {
    snprintf(line, sizeof(line), "Water alert: %-4s        ",
             waterAlert == WA_FULL ? "DAY" : (waterAlert == WA_LOW ? "LOW" : "OK"));
    tftLine(46, waterAlert == WA_LOW ? ST77XX_RED
                  : (waterAlert == WA_FULL ? ST77XX_BLUE : ST77XX_WHITE), line);
  }

  // dòng trống cố định — xóa chữ cũ nếu từng hiện trạng thái
  tftLine(60, ST77XX_BLACK, "                        ");

  DBG("[TFT] sensor T=%.1f Dist=%.1f\n", hcTemp, hcDistCm);
}

// ─────────────────────────────────────────────────────────────
//  EEPROM WIFI
// ─────────────────────────────────────────────────────────────
void saveWifiList() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.put(0, wifiCount);
  int addr = sizeof(wifiCount);
  for (int i = 0; i < MAX_WIFI; i++) {
    EEPROM.put(addr, wifiList[i]);
    addr += sizeof(WifiEntry);
  }
  EEPROM.commit();
  EEPROM.end();
}

void loadWifiList() {
  EEPROM.begin(EEPROM_SIZE);
  EEPROM.get(0, wifiCount);
  if (wifiCount < 0 || wifiCount > MAX_WIFI) wifiCount = 0;
  int addr = sizeof(wifiCount);
  for (int i = 0; i < MAX_WIFI; i++) {
    EEPROM.get(addr, wifiList[i]);
    addr += sizeof(WifiEntry);
  }
  EEPROM.end();
}

void addOrUpdateWifi(const String& ssid, const String& pass) {
  for (int i = 0; i < wifiCount; i++) {
    if (ssid == wifiList[i].ssid) {
      pass.toCharArray(wifiList[i].pass, sizeof(wifiList[i].pass));
      saveWifiList();
      return;
    }
  }
  if (wifiCount < MAX_WIFI) {
    ssid.toCharArray(wifiList[wifiCount].ssid, sizeof(wifiList[wifiCount].ssid));
    pass.toCharArray(wifiList[wifiCount].pass, sizeof(wifiList[wifiCount].pass));
    wifiCount++;
  } else {
    for (int i = 0; i < MAX_WIFI - 1; i++) wifiList[i] = wifiList[i + 1];
    ssid.toCharArray(wifiList[MAX_WIFI - 1].ssid, sizeof(wifiList[MAX_WIFI - 1].ssid));
    pass.toCharArray(wifiList[MAX_WIFI - 1].pass, sizeof(wifiList[MAX_WIFI - 1].pass));
  }
  saveWifiList();
}

// Chờ STA — poll 100ms (không delay 500ms)
bool waitWifiConnected(uint16_t maxMs = 12000) {
  const uint16_t step = 100;
  uint16_t waited = 0;
  while (waited < maxMs) {
    wl_status_t st = WiFi.status();
    if (st == WL_CONNECTED) return true;
    // Sai mật khẩu / không thấy AP → thoát sớm, đừng chờ đủ maxMs
    if (st == WL_CONNECT_FAILED || st == WL_NO_SSID_AVAIL) {
      Serial.printf("\n[WiFi] fail status=%d\n", (int)st);
      return false;
    }
    delay(step);
    waited += step;
    if ((waited % 500) == 0) Serial.print(".");
  }
  return WiFi.status() == WL_CONNECTED;
}

bool tryWifiCreds(const char* ssid, const char* pass) {
  Serial.printf("[WiFi] STA begin '%s'\n", ssid);
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.disconnect(true);
  delay(200);
  WiFi.begin(ssid, pass);
  if (waitWifiConnected(12000)) {
    Serial.println("\n[WiFi] OK IP: " + WiFi.localIP().toString());
    return true;
  }
  Serial.printf("\n[WiFi] FAIL status=%d\n", (int)WiFi.status());
  WiFi.disconnect(true);
  return false;
}

bool connectBestWifi() {
  if (wifiCount <= 0) return false;

  // Ưu tiên mạng mới nhất (vừa lưu từ portal) — bỏ scan
  int last = wifiCount - 1;
  if (tryWifiCreds(wifiList[last].ssid, wifiList[last].pass)) return true;

  // Thử các mạng còn lại
  for (int w = last - 1; w >= 0; w--) {
    if (tryWifiCreds(wifiList[w].ssid, wifiList[w].pass)) return true;
  }
  return false;
}

// Forward declare — processPendingStaConnect gọi lại portal khi STA fail
void startPortal();

void processPendingStaConnect() {
  if (!pendingStaConnect || millis() < pendingStaAt) return;
  pendingStaConnect = false;

  Serial.printf("[PORTAL] Dung AP, thu STA '%s'...\n", pendingSsid);
  dnsServer.stop();
  webServer.stop();
  WiFi.softAPdisconnect(true);
  delay(250);

  if (tryWifiCreds(pendingSsid, pendingPass)) {
    Serial.println("[PORTAL] STA OK — restart sang che do binh thuong");
    delay(300);
    ESP.restart();
    return;
  }

  Serial.println("[PORTAL] STA FAIL — mo lai AP de thu lai");
  startPortal();
}

// ─────────────────────────────────────────────────────────────
//  MQTT (giống NgungTu / AloT)
// ─────────────────────────────────────────────────────────────
void mqttPub(const char* device, const String& payload, bool retain = true) {
  if (!mqttClient.isConnected()) {
    DBG("[MQTT] PUB skip (chua ket noi): %s\n", device);
    return;
  }
  String topic = "tele/" + String(device) + "/status";
  bool ok = mqttClient.publish(topic, payload, retain, 0);
  DBG("[MQTT] PUB %s => %s | %s\n", topic.c_str(), payload.c_str(), ok ? "OK" : "FAIL");
}

void pubOnline() { mqttPub(CHIP_ID, "online", true); }

void pubTemp() {
  if (isnan(hcTemp)) return;
  mqttPub(DEV_TEMP, "{\"value\":" + String(hcTemp, 1) + "}", true);
}
void pubHumi() {
  if (isnan(hcHum)) return;
  mqttPub(DEV_HUMI, "{\"value\":" + String(hcHum, 1) + "}", true);
}
void pubPh() {
  if (isnan(hcPh)) return;
  mqttPub(DEV_PH, "{\"value\":" + String(hcPh, 2) + "}", true);
}
void pubTds() {
  mqttPub(DEV_TDS, "{\"value\":" + String(hcTds, 0) + "}", true);
}
void pubWater() {
  mqttPub(DEV_WATER, "{\"value\":" + String(hcWaterPct, 0) + "}", true);
}
void pubDist() {
  if (isnan(hcDistCm)) return;
  mqttPub(DEV_DIST, "{\"value\":" + String(hcDistCm, 1) + "}", true);
}
void pubWaterAlert() {
  const char* al = (waterAlert == WA_FULL) ? "FULL" :
                   (waterAlert == WA_LOW)  ? "LOW"  : "OK";
  mqttPub(DEV_WATER_AL, "{\"value\":\"" + String(al) + "\"}", true);
}
void pubLight() {
  mqttPub(DEV_LIGHT, "{\"value\":" + String(hcLightPct) + "}", true);
}
void pubPump() {
  mqttPub(DEV_PUMP, pumpOn ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}", true);
}
void pubLamp() {
  mqttPub(DEV_LAMP, lightOn ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}", true);
}
void pubStatus() {
  String safe = String(statusMsg);
  safe.replace("\"", "'");
  mqttPub(DEV_STATUS, "{\"value\":\"" + safe + "\"}", true);
}
void pubPower() {
  mqttPub(DEV_POWER, systemEnabled ? "{\"value\":\"ON\"}" : "{\"value\":\"OFF\"}", true);
}

void publishTelemetry() {
  DBG("[MQTT] ===== TELEMETRY chip=%s =====\n", CHIP_ID);
  pubTemp();
  wsClient.loop();
  pubHumi();
  wsClient.loop();
  pubPh();
  wsClient.loop();
  pubTds();
  wsClient.loop();
  pubWater();
  wsClient.loop();
  pubDist();
  wsClient.loop();
  pubWaterAlert();
  wsClient.loop();
  pubLight();
  wsClient.loop();
  pubPump();
  wsClient.loop();
  pubLamp();
  wsClient.loop();
  pubStatus();
  wsClient.loop();
  pubPower();
  DBG("[MQTT] ===== TELEMETRY xong heap=%u =====\n", ESP.getFreeHeap());
}

HcMode parseHcMode(const String& s) {
  if (s == "ON" || s == "1") return HC_ON;
  if (s == "OFF" || s == "0") return HC_OFF;
  return HC_AUTO;
}

void mqttCallback(const String& topicStr, const String& payload, const size_t size) {
  (void)size;
  String topic = topicStr;
  String cmd = payload;
  cmd.trim();
  cmd.toUpperCase();
  Serial.printf("Nhan lenh [%s]: %s\n", topic.c_str(), cmd.c_str());

  if (topic.indexOf(DEV_POWER) >= 0) {
    if (cmd == "ON" || cmd == "1") {
      systemEnabled = true;
      statusMsg = "Bat tu App";
    } else if (cmd == "OFF" || cmd == "0") {
      systemEnabled = false;
      statusMsg = "Tat tu App";
    }
    updateActuators();
    pubPower();
    pubPump();
    pubLamp();
    pubStatus();
    return;
  }

  if (topic.indexOf(DEV_PUMP) >= 0) {
    pumpMode = parseHcMode(cmd);
    updateActuators();
    pubPump();
    pubStatus();
    return;
  }

  if (topic.indexOf(DEV_LAMP) >= 0) {
    lightMode = parseHcMode(cmd);
    updateActuators();
    pubLamp();
    pubStatus();
  }
}

void reconnectMQTT() {
  if (mqttClient.isConnected()) return;
  if (!wsClient.isConnected()) {
    Serial.println("[MQTT] Cho WebSocket SSL...");
    return;
  }
  wssReady = true;

  uint32_t chipMac = (uint32_t)ESP.getEfuseMac();
  String clientId = "ESP32-HC-" + String(chipMac, HEX);
  String lwtTopic = "tele/" + String(CHIP_ID) + "/status";

  Serial.printf("[MQTT] CONNECT %s ...\n", clientId.c_str());
  mqttClient.setWill(lwtTopic, "offline", true, 1);

  if (mqttClient.connect(clientId, "", "")) {
    mqttLoggedOk = true;
    Serial.println("[MQTT] CONNECTED!");
    pubOnline();
    wsClient.loop();
    delay(50);

    mqttClient.subscribe("cmnd/" + String(DEV_POWER) + "/POWER", [](const char* payload, unsigned int size) {
      String cmd = "";
      for (unsigned int i = 0; i < size; i++) cmd += payload[i];
      mqttCallback("cmnd/" + String(DEV_POWER) + "/POWER", cmd, size);
    });
    wsClient.loop();
    delay(50);

    mqttClient.subscribe("cmnd/" + String(DEV_PUMP) + "/POWER", [](const char* payload, unsigned int size) {
      String cmd = "";
      for (unsigned int i = 0; i < size; i++) cmd += payload[i];
      mqttCallback("cmnd/" + String(DEV_PUMP) + "/POWER", cmd, size);
    });
    wsClient.loop();
    delay(50);

    mqttClient.subscribe("cmnd/" + String(DEV_LAMP) + "/POWER", [](const char* payload, unsigned int size) {
      String cmd = "";
      for (unsigned int i = 0; i < size; i++) cmd += payload[i];
      mqttCallback("cmnd/" + String(DEV_LAMP) + "/POWER", cmd, size);
    });
    wsClient.loop();
    delay(50);

    publishTelemetry();
  } else {
    mqttLoggedOk = false;
    Serial.println("[MQTT] CONNECT FAIL");
  }
}

// ─────────────────────────────────────────────────────────────
//  WEB PORTAL
// ─────────────────────────────────────────────────────────────
const char PORTAL_HTML[] PROGMEM = R"rawhtml(
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ThuyCanh Setup</title>
<style>body{font-family:sans-serif;background:#0a1a12;color:#e2e8f0;display:flex;justify-content:center;padding:20px}
.c{max-width:400px;width:100%;} input{width:100%;padding:10px;margin-bottom:10px;border-radius:5px;border:none} button{padding:10px;width:100%;background:#22c55e;color:#fff;border:none;border-radius:5px;cursor:pointer;font-weight:bold}
#st{margin-top:15px;text-align:center;font-weight:bold;padding:10px;border-radius:5px;display:none;}</style>
</head><body><div class="c"><h2>Thuy Canh IoT WiFi</h2>
<button onclick="scan()" style="margin-bottom:10px;background:#16a34a;">Quet mang xung quanh</button><div id="w" style="margin-bottom:10px;line-height:1.8;cursor:pointer;"></div>
<input id="s" placeholder="Ten WiFi"><input type="password" id="p" placeholder="Mat khau">
<button onclick="conn()">Ket noi</button><div id="st"></div></div>
<script>
function scan() {
  document.getElementById('w').innerHTML = 'Dang quet...';
  fetch('/scan').then(r => r.json()).then(l => {
    document.getElementById('w').innerHTML = l.map(n =>
      `<div style="padding:5px; background:#14532d; margin-top:5px; border-radius:5px;" onclick="document.getElementById('s').value='${n.ssid}'">${n.ssid} (${n.rssi}dBm)</div>`
    ).join('');
  }).catch(e => { document.getElementById('w').innerHTML = 'Loi quet mang'; });
}
function conn() {
  const s = document.getElementById('s').value;
  const p = document.getElementById('p').value;
  if (!s) { alert('Nhap ten WiFi!'); return; }
  const st = document.getElementById('st');
  st.style.display = 'block';
  st.style.background = '#22c55e';
  st.innerHTML = 'Dang gui... may se restart va ket noi WiFi.';
  // Form POST (khong dung fetch) — captive portal on dinh hon, luon thay trang ket qua
  const f = document.createElement('form');
  f.method = 'POST';
  f.action = '/connect';
  const a = document.createElement('input'); a.name = 'ssid'; a.value = s; f.appendChild(a);
  const b = document.createElement('input'); b.name = 'pass'; b.value = p; f.appendChild(b);
  document.body.appendChild(f);
  f.submit();
}
</script></body></html>
)rawhtml";

void handleNotFound() {
  webServer.sendHeader("Location", "http://192.168.4.1/", true);
  webServer.send(302, "text/plain", "");
}
void handleRoot() { webServer.send_P(200, "text/html", PORTAL_HTML); }

void handleScan() {
  WiFi.mode(WIFI_AP_STA);
  delay(30);
  int n = WiFi.scanNetworks(false, false, false, 120);
  String json = "[";
  if (n > 0) {
    for (int i = 0; i < n; i++) {
      if (i) json += ",";
      String ssid = WiFi.SSID(i);
      ssid.replace("\\", "\\\\");
      ssid.replace("\"", "\\\"");
      json += "{\"ssid\":\"" + ssid + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
    }
    WiFi.scanDelete();
  }
  json += "]";
  // Giữ AP; tắt STA scan
  WiFi.mode(WIFI_AP);
  webServer.send(200, "application/json", json);
}

void handleConnect() {
  String ssid = webServer.arg("ssid");
  String pass = webServer.arg("pass");
  if (ssid.length() == 0) {
    webServer.send(200, "text/html",
                   "<html><body style='background:#0a1a12;color:#fff;padding:24px;font-family:sans-serif'>"
                   "<h2>Loi</h2><p>Chua nhap ten WiFi.</p>"
                   "<a style='color:#4ade80' href='/'>Quay lai</a></body></html>");
    return;
  }
  if (ssid.length() > 32) {
    webServer.send(200, "text/html",
                   "<html><body style='background:#0a1a12;color:#fff;padding:24px;font-family:sans-serif'>"
                   "<h2>Loi</h2><p>Ten WiFi qua dai.</p>"
                   "<a style='color:#4ade80' href='/'>Quay lai</a></body></html>");
    return;
  }

  // Lưu → hiện trang thành công (điện thoại còn trên AP) → restart → STA thuần
  addOrUpdateWifi(ssid, pass);
  Serial.printf("[PORTAL] Da luu '%s' (pass len=%u) — trang OK roi restart\n",
                ssid.c_str(), (unsigned)pass.length());

  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'>"
                "<meta name='viewport' content='width=device-width,initial-scale=1'>"
                "<title>Da luu</title></head>"
                "<body style='background:#0a1a12;color:#e2e8f0;font-family:sans-serif;padding:28px;text-align:center'>"
                "<h2 style='color:#4ade80'>Da luu WiFi!</h2>"
                "<p>May dang <b>restart</b> de ket noi <b>";
  html += ssid;
  html += "</b>.</p>"
          "<p style='color:#94b8a6'>Doi 15–20 giay. Mat WiFi ThuyCanh la binh thuong.</p>"
          "<p>Neu that bai: noi lai <b>ThuyCanh</b>, kiem tra mat khau (dung 2.4GHz).</p>"
          "</body></html>";

  webServer.send(200, "text/html", html);
  webServer.client().flush();
  delay(2000);  // đủ thời gian điện thoại tải xong trang
  ESP.restart();
}

void startPortal() {
  portalActive = true;
  pendingStaConnect = false;
  setRelay(PIN_PUMP, false);
  setRelay(PIN_LIGHT, false);
  Serial.println("\n[PORTAL] Khoi tao AP nhanh...");

  WiFi.persistent(false);
  WiFi.disconnect(true);
  delay(50);
  WiFi.mode(WIFI_OFF);
  delay(80);
  WiFi.mode(WIFI_AP);
  delay(50);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  // AP mở (không mật khẩu) — điện thoại vào nhanh hơn
  bool apOk = WiFi.softAP(AP_SSID, nullptr, 1, 0, 4);
  Serial.printf("[PORTAL] softAP=%s  SSID=%s  IP=%s\n",
                apOk ? "OK" : "FAIL", AP_SSID, WiFi.softAPIP().toString().c_str());

  dnsServer.stop();
  dnsServer.start(DNS_PORT, "*", apIP);
  webServer.stop();
  webServer.on("/", HTTP_GET, handleRoot);
  webServer.on("/scan", HTTP_GET, handleScan);
  webServer.on("/connect", HTTP_POST, handleConnect);
  webServer.onNotFound(handleNotFound);
  webServer.begin();

  Serial.println("[PORTAL] Vao WiFi 'ThuyCanh' → http://192.168.4.1");
  statusMsg = "Cau hinh mang";
}

void checkBootButtonForPortal() {
  bool pressed = (digitalRead(PIN_BOOT_BTN) == LOW);
  if (pressed) {
    if (!bootWasPressed) {
      bootWasPressed = true;
      bootPressStart = millis();
    } else if (millis() - bootPressStart >= BOOT_HOLD_MS) {
      wifiCount = 0;
      memset(wifiList, 0, sizeof(wifiList));
      saveWifiList();
      WiFi.disconnect(true);
      startPortal();
      bootWasPressed = false;
    }
  } else {
    bootWasPressed = false;
  }
}

void checkDoubleReset() {
  if (rtcMagic == DOUBLE_RESET_MAGIC) {
    isDoubleReset = true;
    rtcMagic = 0;
    wifiCount = 0;
    saveWifiList();
    Serial.println("DOUBLE RESET — xoa WiFi, mo Portal");
  } else {
    isDoubleReset = false;
    rtcMagic = DOUBLE_RESET_MAGIC;
  }
}

void clearDoubleResetFlag() {
  if (rtcMagic == DOUBLE_RESET_MAGIC) rtcMagic = 0;
}

// ─────────────────────────────────────────────────────────────
//  SETUP / LOOP
// ─────────────────────────────────────────────────────────────
void debugPrintPinMap() {
  Serial.println("---------- PIN MAP (DEBUG) ----------");
  Serial.printf("  DHT22      GPIO %d\n", PIN_DHT);
  Serial.printf("  LDR        GPIO %d\n", PIN_LDR);
  Serial.printf("  pH         GPIO %d\n", PIN_PH);
  Serial.printf("  TDS        GPIO %d (ENABLE=%d)\n", PIN_TDS, (int)ENABLE_TDS);
  Serial.printf("  HC-SR04    TRIG %d  ECHO %d\n", PIN_TRIG, PIN_ECHO);
  Serial.printf("  TFT SPI    SCL=%d SDA/MOSI=%d RES=%d DC=%d CS=GND BLK=3.3V\n",
                TFT_SCLK, TFT_MOSI, TFT_RST, TFT_DC);
  Serial.printf("  Relay CH1  BOM  GPIO %d\n", PIN_PUMP);
  Serial.printf("  Relay CH2  DEN  GPIO %d\n", PIN_LIGHT);
  Serial.printf("  CHIP_ID    %s\n", CHIP_ID);
  Serial.printf("  MQTT       %s:%d%s\n", MQTT_HOST, MQTT_PORT, MQTT_PATH);
  Serial.printf("  Water      FULL<=%.0fcm  EMPTY>=%.0fcm\n", DIST_FULL_CM, DIST_EMPTY_CM);
  Serial.printf("  Light AUTO ON<%d%% OFF>%d%%\n", LIGHT_ON_BELOW_PCT, LIGHT_OFF_ABOVE_PCT);
  Serial.printf("  DEBUG_SERIAL=%d\n", DEBUG_SERIAL);
  Serial.println("-------------------------------------");
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  THUY CANH IoT STEM — ESP32 DEBUG");
  Serial.printf("  CHIP_ID = %s  (app chi nhan chip nay)\n", CHIP_ID);
  Serial.println("  Serial Monitor: 115200 baud\n");
  Serial.printf("Free heap: %u bytes\n", ESP.getFreeHeap());
  Serial.printf("Reset reason: %d\n", (int)esp_reset_reason());
  debugPrintPinMap();

  pinMode(PIN_BOOT_BTN, INPUT_PULLUP);
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_PUMP, OUTPUT);
  pinMode(PIN_LIGHT, OUTPUT);
  DBG_LN("[SETUP] Relay OFF luc khoi dong");
  setRelay(PIN_PUMP, false);
  setRelay(PIN_LIGHT, false);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  dht.begin();
  DBG_LN("[SETUP] DHT22 begin");

  // ----- TFT ST7735 SPI 80x160 -----
  // CS -> GND, BLK -> 3.3V (không dùng GPIO ESP32)

  Serial.println("[TFT] Init ST7735 80x160 SPI ...");
  Serial.println("  GND->GND VCC->3.3V SCL->22 SDA->21 RES->17 DC->18 CS->GND BLK->3.3V");

#if TFT_INIT_MODE == 1
  tft.initR(INITR_MINI160x80_PLUGIN);
  Serial.println("[TFT] initR MINI160x80_PLUGIN");
#elif TFT_INIT_MODE == 2
  tft.initR(INITR_BLACKTAB);
  Serial.println("[TFT] initR BLACKTAB");
#else
  tft.initR(INITR_MINI160x80);
  Serial.println("[TFT] initR MINI160x80");
#endif

  tft.setRotation(1);  // ngang 160x80
#if TFT_INVERT
  tft.invertDisplay(true);
#endif
  tft.fillScreen(ST77XX_BLACK);  // chỉ xóa 1 lần lúc khởi động
  tftOK = true;
  Serial.println("[TFT] OK — chi hien cam bien, khong fillScreen moi lan ve");
  lastTft = 0;

  // WiFi / Portal TRƯỚC WSS — AP lên nhanh, không chờ SSL
  loadWifiList();
  DBG("[SETUP] WiFi da luu: %d mang\n", wifiCount);
  checkDoubleReset();

  if (isDoubleReset || wifiCount <= 0) {
    DBG_LN("[SETUP] Mo Portal ngay (chua co WiFi / double-reset)");
    startPortal();
  } else if (!connectBestWifi()) {
    DBG_LN("[SETUP] STA fail -> Portal");
    startPortal();
  } else {
    DBG("[SETUP] WiFi OK IP=%s RSSI=%d\n",
        WiFi.localIP().toString().c_str(), WiFi.RSSI());
  }

  // MQTT WSS chỉ khi đã có WiFi (không chạy trong portal)
  if (!portalActive) {
    Serial.printf("[WSS] beginSSL %s:%d%s\n", MQTT_HOST, MQTT_PORT, MQTT_PATH);
    wsClient.beginSSL(MQTT_HOST, MQTT_PORT, MQTT_PATH);
    wsClient.setExtraHeaders("Sec-WebSocket-Protocol: mqtt");
    wsClient.setReconnectInterval(5000);
    wsClient.onEvent([](WStype_t type, uint8_t* payload, size_t length) {
      (void)length;
      switch (type) {
        case WStype_DISCONNECTED:
          wssReady = false;
          mqttLoggedOk = false;
          Serial.println("[WSS] DISCONNECTED");
          break;
        case WStype_CONNECTED:
          wssReady = true;
          Serial.printf("[WSS] CONNECTED → %s\n", payload ? (const char*)payload : MQTT_HOST);
          lastMqttRetry = 0;
          break;
        case WStype_ERROR:
          wssReady = false;
          Serial.println("[WSS] ERROR");
          break;
        default:
          break;
      }
    });
    mqttClient.begin(wsClient);
    mqttClient.setTimeout(8000);
  }

  statusMsg = portalActive ? "Cau hinh mang" : "San sang";
  Serial.println("[SETUP] Xong — mo Serial theo doi [PORTAL]/[SENSOR]/[MQTT]");
  Serial.println("========================================\n");
}

void loop() {
  if (millis() > 3000 && rtcMagic == DOUBLE_RESET_MAGIC) {
    clearDoubleResetFlag();
  }

  if (!portalActive) checkBootButtonForPortal();

  readSensors();
  drawOLED();

  if (portalActive) {
    dnsServer.processNextRequest();
    webServer.handleClient();
    delay(10);
    return;
  }

  unsigned long now = millis();

  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastReconnect >= RECONNECT_MS) {
      lastReconnect = now;
      if (connectBestWifi()) {
        wifiRetries = 0;
      } else {
        wifiRetries++;
        // Sai mật khẩu / mất WiFi → về portal sớm hơn (không chờ 3x10s)
        if (wifiRetries >= 2) {
          startPortal();
          wifiRetries = 0;
        }
      }
    }
    delay(50);
    return;
  }
  wifiRetries = 0;

  wsClient.loop();
  mqttClient.update();

  if (!mqttClient.isConnected()) {
    if (now - lastMqttRetry >= 5000) {
      lastMqttRetry = now;
      if (wsClient.isConnected()) wssReady = true;
      Serial.printf("[DEBUG] wifi=%d ws=%d mqtt=%d\n",
                    WiFi.status() == WL_CONNECTED,
                    wsClient.isConnected(),
                    mqttClient.isConnected());
      reconnectMQTT();
    }
  } else if (!mqttLoggedOk) {
    mqttLoggedOk = true;
  }

  if (now - lastHeartbeat >= HEARTBEAT_MS) {
    lastHeartbeat = now;
    DBG_LN("[MQTT] heartbeat online");
    pubOnline();
  }

  if (now - lastTelemetry >= TELEMETRY_MS) {
    lastTelemetry = now;
    publishTelemetry();
    const char* al = (waterAlert == WA_FULL) ? "FULL" :
                     (waterAlert == WA_LOW)  ? "LOW"  : "OK";
    Serial.println("---------- SNAPSHOT ----------");
    Serial.printf("  chip=%s  wifi=%s  rssi=%d  mqtt=%d  ws=%d  heap=%u\n",
                  CHIP_ID,
                  WiFi.status() == WL_CONNECTED ? "OK" : "FAIL",
                  WiFi.RSSI(),
                  mqttClient.isConnected(),
                  wsClient.isConnected(),
                  ESP.getFreeHeap());
    Serial.printf("  T=%.1fC  H=%.0f%%  pH=%.2f  TDS=%.0f  Light=%d%%\n",
                  hcTemp, hcHum, hcPh, hcTds, hcLightPct);
    Serial.printf("  Dist=%.1fcm  Water=%.0f%%  alert=%s\n",
                  hcDistCm, hcWaterPct, al);
    Serial.printf("  Bom=%s (mode=%d)  Den=%s (mode=%d)  Sys=%s\n",
                  pumpOn ? "ON" : "OFF", (int)pumpMode,
                  lightOn ? "ON" : "OFF", (int)lightMode,
                  systemEnabled ? "ON" : "OFF");
    Serial.printf("  status=\"%s\"\n", statusMsg);
    Serial.println("------------------------------");
  }

  delay(50);
}
