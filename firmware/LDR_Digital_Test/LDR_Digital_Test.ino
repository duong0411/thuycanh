/*
 * TEST CẢM BIẾN QUANG (LDR) — DIGITAL 0/1
 *
 * Nối dây:
 *   Module LDR DO  -> GPIO 34  (ESP32)
 *   VCC            -> 3.3V
 *   GND            -> GND
 *   (Không dùng chân AO)
 *
 * Serial Monitor: 115200
 * Che cảm biến / chiếu sáng → xem 0 đổi thành 1 (hoặc ngược lại).
 */

#define PIN_LDR  34

// Nếu đọc ngược (tối=1, sáng=0) mà bạn muốn đảo hiển thị: đặt 1
#define LIGHT_INVERT_DO  0

void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(PIN_LDR, INPUT);

  Serial.println();
  Serial.println("======== TEST LDR DIGITAL ========");
  Serial.printf("Pin DO -> GPIO %d\n", PIN_LDR);
  Serial.println("0 = TOI (bat den) | 1 = SANG (tat den)");
  Serial.println("Che / soi den vao cam bien de test...");
  Serial.println("==================================");
}

void loop() {
  int raw = (digitalRead(PIN_LDR) == HIGH) ? 1 : 0;
#if LIGHT_INVERT_DO
  int val = 1 - raw;
#else
  int val = raw;
#endif

  Serial.printf("RAW=%d  Light=%d  (%s)\n",
                raw, val, (val == 0) ? "TOI" : "SANG");

  delay(300);
}
