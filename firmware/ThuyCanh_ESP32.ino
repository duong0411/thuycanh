/*
 * ╔══════════════════════════════════════════════════════════════╗
 * ║     THỦY CANH IoT — STEM (ESP32) + MQTT APP (AloT WSS)      ║
 * ╠══════════════════════════════════════════════════════════════╣
 * ║  ✅ DHT22 + LDR + pH + HC-SR04 (+ TDS tùy chọn)             ║
 * ║  ✅ OLED SSD1306 + Relay bơm / đèn                          ║
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
 * 4. Adafruit SSD1306 + Adafruit GFX
 *
 * APP: mở folder thuycanh/ — chipId = 790 (KHÔNG dùng 789 của máy Ngưng Tụ)
 *
 * Sơ đồ chân:
 *   DHT22     -> GPIO 4
 *   LDR       -> GPIO 34 (analog)
 *   pH        -> GPIO 35 (analog)
 *   TDS       -> GPIO 32 (analog, tùy chọn)
 *   HC-SR04   -> TRIG GPIO 12, ECHO GPIO 13
 *   OLED I2C  -> SDA GPIO 21, SCL GPIO 22
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
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <esp_system.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

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
  char ssid[32];
  char pass[32];
};
WifiEntry wifiList[MAX_WIFI];
int wifiCount = 0;

// ─────────────────────────────────────────────────────────────
//  ĐỐI TƯỢNG
// ─────────────────────────────────────────────────────────────
Adafruit_SSD1306 oled(128, 64, &Wire, -1);
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
bool oledOK = false;

unsigned long tRead = 0;
const char* statusMsg = "Khoi dong";

// ─────────────────────────────────────────────────────────────
//  BIẾN WIFI / MQTT
// ─────────────────────────────────────────────────────────────
bool portalActive = false;
unsigned long lastTelemetry = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastReconnect = 0;
unsigned long lastMqttRetry = 0;
unsigned long lastOled = 0;
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
  if (dur == 0) return -1.0f;

  // cm = us * 0.0343 / 2  (tránh chia float chậm hơn nhân)
  float cm = dur * 0.01715f;
  if (cm < DIST_MIN_CM || cm > DIST_MAX_CM) return -1.0f;
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
    return distKf.x;
  }

  // Spike vừa: tăng R (ít tin đo hơn)
  float R = KF_R;
  if (innov > KF_OUTLIER_CM || innov < -KF_OUTLIER_CM) {
    R = KF_R * 6.0f;
  }

  float K = distKf.P / (distKf.P + R);
  distKf.x += K * innov;
  distKf.P *= (1.0f - K);
  // giữ P trong biên nhỏ để tránh số học lệch lâu dài
  if (distKf.P < 0.01f) distKf.P = 0.01f;
  if (distKf.P > 10.0f) distKf.P = 10.0f;
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

  if (n == 0) return -1.0f;

  float z;
  if (n == 1) z = s0;
  else if (n == 2) z = 0.5f * (s0 + s1);
  else z = median3(s0, s1, s2);

  return distKalmanUpdate(z);
}

float distanceToPercent(float dCm) {
  float pct = (DIST_EMPTY_CM - dCm) * 100.0f / (DIST_EMPTY_CM - DIST_FULL_CM);
  return constrain(pct, 0.0f, 100.0f);
}

// Cập nhật mức nước + cảnh báo FULL/LOW (có hysteresis)
void updateWaterLevel(float dCm) {
  if (dCm < 0) return;
  hcDistCm = dCm;
  hcWaterPct = distanceToPercent(dCm);

  if (waterAlert == WA_FULL) {
    if (dCm >= DIST_FULL_CM + DIST_HYST_CM) waterAlert = WA_OK;
  } else if (waterAlert == WA_LOW) {
    if (dCm <= DIST_EMPTY_CM - DIST_HYST_CM) waterAlert = WA_OK;
  }

  if (waterAlert != WA_FULL && dCm <= DIST_FULL_CM) waterAlert = WA_FULL;
  if (waterAlert != WA_LOW && dCm >= DIST_EMPTY_CM) waterAlert = WA_LOW;
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
}

void readSensors() {
  if (millis() - tRead < READ_MS) return;
  tRead = millis();

  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t)) hcTemp = t;
  if (!isnan(h)) hcHum = h;

  hcPh = readPH();
  hcLightPct = readLightPercent();

  float d = readDistanceFilteredCm();
  if (d > 0.0f) updateWaterLevel(d);

  // Doc TDS de hien OLED/MQTT (neu co cam bien)
  if (ENABLE_TDS) hcTds = readTDS(hcTemp);

  if (!portalActive) updateActuators();
}

void drawOLED() {
  if (!oledOK) return;
  if (millis() - lastOled < 400) return;
  lastOled = millis();

  oled.clearDisplay();
  oled.setTextSize(1);
  oled.setTextColor(SSD1306_WHITE);

  if (portalActive) {
    oled.setCursor(0, 0);  oled.println("CAU HINH MANG");
    oled.setCursor(0, 14); oled.println("Ket noi: ThuyCanh");
    oled.setCursor(0, 28); oled.println("Mo: 192.168.4.1");
    oled.setCursor(0, 48); oled.printf("Da luu: %d mang", wifiCount);
    oled.display();
    return;
  }

  // 128x64 — 8 dong x 8px: hien thi day du cam bien de theo doi
  // Dong 0: Nhiet do + Do am
  oled.setCursor(0, 0);
  oled.print("T:");
  if (isnan(hcTemp)) oled.print("--.-");
  else oled.print(hcTemp, 1);
  oled.print("C H:");
  if (isnan(hcHum)) oled.print("--");
  else oled.print(hcHum, 0);
  oled.print("%");

  // Dong 1: pH + TDS
  oled.setCursor(0, 8);
  oled.print("pH:");
  if (isnan(hcPh)) oled.print("--.-");
  else oled.print(hcPh, 2);
  oled.print(" TDS:");
  if (ENABLE_TDS) oled.print(hcTds, 0);
  else oled.print("--");

  // Dong 2: Khoang cach + % muc nuoc
  oled.setCursor(0, 16);
  oled.print("Dist:");
  if (isnan(hcDistCm)) oled.print("--.-");
  else oled.print(hcDistCm, 1);
  oled.print("cm ");
  oled.print(hcWaterPct, 0);
  oled.print("%");

  // Dong 3: Anh sang + canh bao muc nuoc
  oled.setCursor(0, 24);
  oled.print("Light:");
  oled.print(hcLightPct);
  oled.print("% ");
  if (waterAlert == WA_FULL) oled.print("DAY");
  else if (waterAlert == WA_LOW) oled.print("THAP");
  else oled.print("OK");

  // Dong 4: Relay CH1 bom + CH2 den (AUTO theo LDR)
  oled.setCursor(0, 32);
  oled.print("Bom:");
  oled.print(pumpOn ? "ON " : "OFF");
  oled.print(" Den:");
  oled.print(lightOn ? "ON" : "OFF");
  if (lightMode == HC_AUTO) oled.print("*");  // * = dang AUTO theo anh sang

  // Dong 5: He thong + WiFi
  oled.setCursor(0, 40);
  oled.print("Sys:");
  oled.print(systemEnabled ? "ON " : "OFF");
  oled.print(" WiFi:");
  oled.print(WiFi.status() == WL_CONNECTED ? "OK" : "--");

  // Dong 6-7: trang thai (2 dong neu dai)
  oled.setCursor(0, 48);
  oled.print("St:");
  // rut gon cho vua man hinh
  if (waterAlert == WA_LOW) oled.print("BOM NUOC NGOAI");
  else if (waterAlert == WA_FULL) oled.print("NUOC DAY-BOM ON");
  else if (!systemEnabled) oled.print("TAT TU APP");
  else if (!isnan(hcPh) && (hcPh < PH_LOW || hcPh > PH_HIGH)) oled.print("pH LECH");
  else oled.print("HOAT DONG TOT");

  oled.setCursor(0, 56);
  oled.print("MQTT:");
  oled.print(mqttClient.isConnected() ? "OK" : "--");
  oled.print(" ID:790");

  oled.display();
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
      pass.toCharArray(wifiList[i].pass, 32);
      saveWifiList();
      return;
    }
  }
  if (wifiCount < MAX_WIFI) {
    ssid.toCharArray(wifiList[wifiCount].ssid, 32);
    pass.toCharArray(wifiList[wifiCount].pass, 32);
    wifiCount++;
  } else {
    for (int i = 0; i < MAX_WIFI - 1; i++) wifiList[i] = wifiList[i + 1];
    ssid.toCharArray(wifiList[MAX_WIFI - 1].ssid, 32);
    pass.toCharArray(wifiList[MAX_WIFI - 1].pass, 32);
  }
  saveWifiList();
}

bool connectBestWifi() {
  if (wifiCount <= 0) return false;
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true);
  delay(100);

  int bestIdx = -1;
  int bestRSSI = -999;
  int n = WiFi.scanNetworks();
  if (n > 0) {
    for (int i = 0; i < n; i++) {
      for (int w = 0; w < wifiCount; w++) {
        if (WiFi.SSID(i) == String(wifiList[w].ssid) && WiFi.RSSI(i) > bestRSSI) {
          bestRSSI = WiFi.RSSI(i);
          bestIdx = w;
        }
      }
    }
    WiFi.scanDelete();
  }
  if (bestIdx < 0) bestIdx = wifiCount - 1;

  Serial.printf("Dang ket noi: %s\n", wifiList[bestIdx].ssid);
  WiFi.begin(wifiList[bestIdx].ssid, wifiList[bestIdx].pass);
  for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi OK! IP: " + WiFi.localIP().toString());
    return true;
  }
  Serial.println("\nKet noi WiFi that bai!");
  return false;
}

// ─────────────────────────────────────────────────────────────
//  MQTT (giống NgungTu / AloT)
// ─────────────────────────────────────────────────────────────
void mqttPub(const char* device, const String& payload, bool retain = true) {
  if (!mqttClient.isConnected()) return;
  String topic = "tele/" + String(device) + "/status";
  mqttClient.publish(topic, payload, retain, 0);
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
  st.innerHTML = 'Dang ket noi...';
  st.style.background = '#334155';
  fetch('/connect', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'ssid=' + encodeURIComponent(s) + '&pass=' + encodeURIComponent(p)
  }).then(r => r.json()).then(d => {
    if (d.ok) {
      st.style.background = '#22c55e';
      st.innerHTML = 'Thanh cong! Dang restart...';
    } else {
      st.style.background = '#ef4444';
      st.innerHTML = 'Loi: ' + (d.message || 'That bai');
    }
  }).catch(e => {
    st.style.background = '#ef4444';
    st.innerHTML = 'Loi mang!';
  });
}
</script></body></html>
)rawhtml";

void handleNotFound() {
  webServer.sendHeader("Location", "http://192.168.4.1/", true);
  webServer.send(302, "text/plain", "");
}
void handleRoot() { webServer.send_P(200, "text/html", PORTAL_HTML); }

void handleScan() {
  int n = WiFi.scanNetworks(false, false);
  if (n < 0) { webServer.send(200, "application/json", "[]"); return; }
  String json = "[";
  for (int i = 0; i < n; i++) {
    if (i) json += ",";
    String ssid = WiFi.SSID(i);
    ssid.replace("\\", "\\\\");
    ssid.replace("\"", "\\\"");
    json += "{\"ssid\":\"" + ssid + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
  }
  json += "]";
  WiFi.scanDelete();
  webServer.send(200, "application/json", json);
}

void handleConnect() {
  String ssid = webServer.arg("ssid");
  String pass = webServer.arg("pass");
  if (ssid.length() > 0) {
    WiFi.begin(ssid.c_str(), pass.c_str());
    for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) delay(500);
    if (WiFi.status() == WL_CONNECTED) {
      addOrUpdateWifi(ssid, pass);
      webServer.send(200, "application/json", "{\"ok\":true}");
      delay(1000);
      ESP.restart();
    } else {
      WiFi.disconnect();
      webServer.send(200, "application/json", "{\"ok\":false,\"message\":\"Sai mat khau hoac WiFi yeu.\"}");
    }
  } else {
    webServer.send(200, "application/json", "{\"ok\":false,\"message\":\"Chua nhap ten WiFi!\"}");
  }
}

void startPortal() {
  portalActive = true;
  setRelay(PIN_PUMP, false);
  setRelay(PIN_LIGHT, false);
  Serial.println("\nKhoi tao AP Portal...");
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  dnsServer.start(DNS_PORT, "*", apIP);
  webServer.on("/", HTTP_GET, handleRoot);
  webServer.on("/scan", HTTP_GET, handleScan);
  webServer.on("/connect", HTTP_POST, handleConnect);
  webServer.onNotFound(handleNotFound);
  webServer.begin();
  Serial.println("Portal OK — ket noi WiFi: ThuyCanh → http://192.168.4.1");
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
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.begin(115200);
  delay(300);
  Serial.println("\n=== THUY CANH ESP32 + MQTT (chip 790) ===");
  Serial.printf("Free heap: %u bytes (Kalman1D ~9B)\n", ESP.getFreeHeap());

  pinMode(PIN_BOOT_BTN, INPUT_PULLUP);
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_PUMP, OUTPUT);
  pinMode(PIN_LIGHT, OUTPUT);
  setRelay(PIN_PUMP, false);
  setRelay(PIN_LIGHT, false);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  dht.begin();

  Wire.begin(21, 22);
  oledOK = oled.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  if (oledOK) {
    oled.clearDisplay();
    oled.setTextSize(1);
    oled.setTextColor(SSD1306_WHITE);
    oled.setCursor(0, 20);
    oled.println("THUY CANH IoT");
    oled.setCursor(0, 36);
    oled.println("Dang khoi dong...");
    oled.display();
  } else {
    Serial.println("Khong tim thay OLED");
  }

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

  loadWifiList();
  checkDoubleReset();

  if (isDoubleReset) {
    startPortal();
  } else if (!(wifiCount > 0 && connectBestWifi())) {
    startPortal();
  }

  statusMsg = "San sang";
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
        if (wifiRetries >= 3) {
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
    pubOnline();
  }

  if (now - lastTelemetry >= TELEMETRY_MS) {
    lastTelemetry = now;
    publishTelemetry();
    Serial.printf("T %.1f H %.0f pH %.2f Dist %.1fcm W %.0f%% alert=%d L %d | Bom %s Den %s | %s | MQTT=%d\n",
                  hcTemp, hcHum, hcPh, hcDistCm, hcWaterPct, (int)waterAlert, hcLightPct,
                  pumpOn ? "ON" : "OFF", lightOn ? "ON" : "OFF", statusMsg,
                  mqttClient.isConnected());
  }

  delay(50);
}
