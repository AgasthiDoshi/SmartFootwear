/*
 * firebase_cloud.cpp
 * Uploads current sensor snapshot to /SmartFootwear/latest
 * and listens for navigation motor commands from /SmartFootwear/commands.
 */
#include "firebase_cloud.h"
#include "fsr_pressure.h"
#include "mpu6050_fall.h"
#include "gait_analysis.h"
#include "haptic_motor.h"

#include <WiFi.h>
#include <Firebase_ESP_Client.h>

FirebaseData footwearFbdo;
FirebaseData footwearCmdFbdo;
FirebaseAuth footwearAuth;
FirebaseConfig footwearConfig;
static bool firebaseStarted = false;

static long long lastExecutedCmdTimestamp = 0;
static String lastExecutedCmdStr = "";

void initFirebaseCloud() {
  Serial.println("Connecting to Wi-Fi...");
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWi-Fi not connected. Uploads will be skipped until reboot.");
    return;
  }

  Serial.print("\nWi-Fi connected. IP: ");
  Serial.println(WiFi.localIP());

  footwearConfig.api_key = FIREBASE_API_KEY;
  footwearConfig.database_url = FIREBASE_DATABASE_URL;
  footwearAuth.user.email = FIREBASE_USER_EMAIL;
  footwearAuth.user.password = FIREBASE_USER_PASSWORD;

  Firebase.reconnectWiFi(true);
  footwearFbdo.setResponseSize(4096);
  footwearCmdFbdo.setResponseSize(1024);
  Firebase.begin(&footwearConfig, &footwearAuth);
  firebaseStarted = true;
  Serial.println("Firebase authentication started.");
}

bool isFirebaseConnected() {
  return firebaseStarted && WiFi.status() == WL_CONNECTED && Firebase.ready();
}

void checkFirebaseCloudCommands() {
  if (WiFi.status() != WL_CONNECTED || !firebaseStarted || !Firebase.ready()) {
    return;
  }

  static unsigned long lastPoll = 0;
  if (millis() - lastPoll < 200) {
    return;
  }
  lastPoll = millis();

  // Read command object from /SmartFootwear/commands sent by the Flutter App
  if (Firebase.RTDB.getJSON(&footwearCmdFbdo, "/SmartFootwear/commands")) {
    FirebaseJson &json = footwearCmdFbdo.jsonObject();
    FirebaseJsonData cmdData, timeData;
    json.get(cmdData, "command");
    json.get(timeData, "timestamp");

    String cmd = cmdData.stringValue;
    long long ts = timeData.int64Value;

    if (cmd.length() > 0 && (ts != lastExecutedCmdTimestamp || cmd != lastExecutedCmdStr)) {
      lastExecutedCmdTimestamp = ts;
      lastExecutedCmdStr = cmd;

      char c = toupper(cmd.charAt(0));
      Serial.printf("\n[CLOUD COMMAND] Received '%c' from App (ts: %lld)\n", c, ts);

      if (c == 'L') {
        Serial.println("[HAPTIC] ➔ LEFT MOTOR ACTIVATED (Turn Left Navigation)");
        hapticPulseLeft(450, 240);
      } else if (c == 'R') {
        Serial.println("[HAPTIC] ➔ RIGHT MOTOR ACTIVATED (Turn Right Navigation)");
        hapticPulseRight(450, 240);
      } else if (c == 'F') {
        Serial.println("[HAPTIC] ➔ BOTH MOTORS PULSED (Arrived / Fall Pattern)");
        hapticPattern_Fall();
      } else if (c == 'S') {
        Serial.println("[HAPTIC] ➔ ALL MOTORS STOPPED");
        hapticStop();
      }
    }
  }
}

bool uploadFootwearData() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Cloud] Wi-Fi disconnected; upload skipped.");
    return false;
  }
  if (!firebaseStarted || !Firebase.ready()) {
    Serial.println("[Cloud] Firebase not ready yet.");
    return false;
  }

  PressureData p = getPressureData();
  float accelG = getAccelMagnitudeG();
  float gyroDps = getGyroMagnitudeDps();
  bool fall = isFallDetected();
  bool contact = isFootInContact();
  unsigned long steps = getStepCount();

  FirebaseJson json;
  json.set("heel_adc", p.heel);
  json.set("midfoot_adc", p.midfoot);
  json.set("forefoot_adc", p.forefoot);
  json.set("acceleration_g", (double)accelG);
  json.set("gyroscope_dps", (double)gyroDps);
  json.set("fall_detected", fall);
  json.set("foot_in_contact", contact);
  json.set("step_count", (double)steps);
  json.set("esp32_online", true);
  json.set("uptime_ms", (double)millis());

  // Also include 9-element sensor array [Heel, Forefoot, Midfoot, AccelX, AccelY, AccelZ, GyroX, GyroY, GyroZ]
  FirebaseJsonArray arr;
  arr.add((double)p.heel);
  arr.add((double)p.forefoot);
  arr.add((double)p.midfoot);
  arr.add((double)getAxG());
  arr.add((double)getAyG());
  arr.add((double)getAzG());
  arr.add((double)getGxDps());
  arr.add((double)getGyDps());
  arr.add((double)getGzDps());
  json.set("sensorValues", arr);

  if (Firebase.RTDB.setJSON(&footwearFbdo, "/SmartFootwear/latest", &json)) {
    Serial.printf("[Cloud] Upload OK -> Accel: %.2fg | Gyro: %.1fdps | Steps: %lu | Fall: %s\n",
                  accelG, gyroDps, steps, fall ? "YES" : "NO");
    return true;
  }

  Serial.print("[Cloud] Firebase error: ");
  Serial.println(footwearFbdo.errorReason());
  return false;
}
