# thuycanh

App Flutter + firmware ESP32 cho dự án **Thủy Canh IoT STEM**.

Theo dõi realtime qua MQTT (broker AloT WSS): nhiệt độ, độ ẩm, pH, TDS, mực nước, ánh sáng, bơm, đèn.

## Tải app (GitHub Actions)

Mỗi push lên `main` sẽ build:

- **Android APK** — cài trực tiếp
- **iOS IPA** — unsigned (cần ký Apple trước khi cài máy thật)

Xem tab **Actions** → artifact, hoặc **Releases**.

## Chạy local

```bash
flutter pub get
flutter run
```

## Chip ID

| Thiết bị | chipId |
|----------|--------|
| Máy Ngưng Tụ | `789` |
| **Thủy Canh IoT** | **`790`** |

## MQTT topics

`tele/<device>/status` với `{"value": ...}`

| Device | Ý nghĩa |
|--------|---------|
| `790` | online / offline |
| `790_temp` | Nhiệt độ (°C) |
| `790_humi` | Độ ẩm (%) |
| `790_ph` | pH |
| `790_tds` | TDS (ppm) |
| `790_water` | Mực nước (%) |
| `790_dist` | Khoảng cách HC-SR04 (cm) |
| `790_water_alert` | `FULL` / `LOW` / `OK` |
| `790_light` | Ánh sáng (%) |
| `790_pump` / `790_lamp` | Bơm / Đèn |
| `790_status` / `790_power` | Trạng thái / nguồn |

Lệnh: `cmnd/790_power|pump|lamp/POWER` → `ON` / `OFF` / `AUTO`

## Mực nước (HC-SR04)

| Khoảng cách | Trạng thái | AUTO |
|-------------|------------|------|
| ≤ **11 cm** | FULL | Bật bơm tuần hoàn |
| ≥ **18 cm** | LOW | Tắt bơm + cảnh báo đổ nước ngoài |
| Giữa 11–18 cm | OK | Bơm tuần hoàn |

### Lọc HC-SR04
Burst 3 mẫu + median + Kalman 1D (~9 byte RAM).

## Firmware

`firmware/ThuyCanh_ESP32.ino` — Board ESP32 Dev Module  
WiFi portal AP: **ThuyCanh** → `http://192.168.4.1`

### Chân kết nối
- DHT22 → GPIO 4  
- LDR → GPIO 34  
- pH → GPIO 35  
- TDS → GPIO 32 (tùy chọn)  
- HC-SR04 → TRIG 12, ECHO 13 (phân áp 5V→3.3V)  
- OLED I2C → SDA 21, SCL 22  
- **Relay 2 kênh**  
  - IN1 (bơm) → GPIO 26  
  - IN2 (đèn) → GPIO 27  
  - Đèn mặc định **AUTO theo LDR**: tối (&lt;30%) bật, sáng (&gt;40%) tắt
