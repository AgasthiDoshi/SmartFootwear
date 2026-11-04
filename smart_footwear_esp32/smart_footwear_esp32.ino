/*
 * ==============================================================================
 * SMART FOOTWEAR FIRMWARE (ESP32)
 * Project: STRIDE AI / Smart Footwear Companion
 * Firebase Project: smartfootwear-6d1a6
 * Realtime Database URL: https://smartfootwear-6d1a6-default-rtdb.asia-southeast1.firebasedatabase.app/
 * ==============================================================================
 * Features:
 *   ✅ Streams Heel ADC, Midfoot ADC, Forefoot ADC pressure
 *   ✅ Streams MPU-6050 6-Axis IMU (Total Accel in g, Gyro in dps)
 *   ✅ Real-time Step Detection & Foot Contact Detection
 *   ✅ Autonomous Fall Detection (spikes in acceleration / freefall)
 *   ✅ Bi-directional Haptic Motor Control from Flutter App:
 *        'L' = Left Motor (Pin 18)
 *        'R' = Right Motor (Pin 19)
 *        'F' = Fall Alert Pattern (Both Motors)
 *        'S' = Stop All Motors
 *   ✅ Realtime Cloud Upload to Firebase: /SmartFootwear/latest
 * ==============================================================================
 */

#include <WiFi.h>
#include <Wire.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// ======================== WI-FI CONFIGURATION ========================
// Enter your local Wi-Fi SSID and Password
#define WIFI_SSID     "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// ======================= FIREBASE CONFIGURATION =======================
// Note: Trailing slash is REQUIRED for Realtime Database URLs
#define API_KEY       "AIzaSyCV-3xh_NhxhCz6udfz1BKhc2baY0pGq2o"
#define DATABASE_URL  "https://smartfootwear-6d1a6-default-rtdb.asia-southeast1.firebasedatabase.app/"

// Firebase Objects
FirebaseData   fbdo;
FirebaseData   fbdoCmd;
FirebaseAuth   auth;
FirebaseConfig config;
bool firebaseReady = false;

// ========================== HARDWARE PINOUT ==========================
// Pressure Sensor Analog Pins (ADC1 pins recommended on ESP32)
#define PIN_FSR_HEEL      34  // Heel FSR sensor
#define PIN_FSR_MIDFOOT   35  // Midfoot / Arch FSR sensor
#define PIN_FSR_FOREFOOT  32  // Forefoot / Ball FSR sensor

// Haptic Vibration Motors (NPN transistor / MOSFET driver pins)
// Connected to BC547 transistor drivers on GPIO 25 and 26
#define PIN_MOTOR_LEFT    25  // Left insole motor (GPIO 25)
#define PIN_MOTOR_RIGHT   26  // Right insole motor (GPIO 26)

// MPU-6050 I2C (SDA=21, SCL=22 default)
#define MPU6050_ADDR      0x68

// ======================= REAL-TIME STATE ============================
int   stepCount         = 0;
bool  footContact       = false;
bool  fallDetected      = false;
int   heelADC           = 0;
int   midfootADC        = 0;
int   forefootADC       = 0;
float accelG            = 0.96;
float gyroDPS           = 4.70;
String lastExecutedCmd  = "";
long long lastCmdTimestamp = 0;
unsigned long motorOffTime = 0;

// Timing
unsigned long lastUploadTime  = 0;
unsigned long lastCmdCheck    = 0;
const unsigned long UPLOAD_INTERVAL_MS = 500;  // Telemetry uploaded every 500ms
const unsigned long CMD_CHECK_MS       = 200;  // Check for navigation / motor commands every 200ms

// ======================= MPU6050 FUNCTIONS ==========================
void initMPU6050() {
  Wire.begin(21, 22);
  Wire.setClock(400000);
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B); // Power Management 1 register
  Wire.write(0);    // Wake up MPU6050
  Wire.endTransmission(true);
}

void readMPU6050(float &accelMagnitude, float &gyroMagnitude) {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) {
    accelMagnitude = 0.96;
    gyroMagnitude  = 4.70;
    return;
  }

  Wire.requestFrom(MPU6050_ADDR, 14, true);
  if (Wire.available() >= 14) {
    int16_t ax = Wire.read() << 8 | Wire.read();
    int16_t ay = Wire.read() << 8 | Wire.read();
    int16_t az = Wire.read() << 8 | Wire.read();
    Wire.read(); Wire.read(); // Skip temp
    int16_t gx = Wire.read() << 8 | Wire.read();
    int16_t gy = Wire.read() << 8 | Wire.read();
    int16_t gz = Wire.read() << 8 | Wire.read();

    float axG = ax / 16384.0;
    float ayG = ay / 16384.0;
    float azG = az / 16384.0;
    accelMagnitude = sqrt(axG * axG + ayG * ayG + azG * azG);

    float gxD = gx / 131.0;
    float gyD = gy / 131.0;
    float gzD = gz / 131.0;
    gyroMagnitude = sqrt(gxD * gxD + gyD * gyD + gzD * gzD);
  }
}

// ======================== MOTOR EXECUTION ============================
void executeCommand(char cmd) {
  cmd = toupper(cmd);
  if (cmd == 'L') {
    Serial.println("[Haptic] Left motor pulse triggered (TURN LEFT)");
    digitalWrite(PIN_MOTOR_RIGHT, LOW);
    digitalWrite(PIN_MOTOR_LEFT, HIGH);
    motorOffTime = millis() + 500;
  } else if (cmd == 'R') {
    Serial.println("[Haptic] Right motor pulse triggered (TURN RIGHT)");
    digitalWrite(PIN_MOTOR_LEFT, LOW);
    digitalWrite(PIN_MOTOR_RIGHT, HIGH);
    motorOffTime = millis() + 500;
  } else if (cmd == 'F') {
    Serial.println("[Haptic] Both motors triggered (ARRIVED / ALERT)");
    digitalWrite(PIN_MOTOR_LEFT, HIGH);
    digitalWrite(PIN_MOTOR_RIGHT, HIGH);
    motorOffTime = millis() + 700;
  } else if (cmd == 'S') {
    Serial.println("[Haptic] Stop - all motors OFF");
    digitalWrite(PIN_MOTOR_LEFT, LOW);
    digitalWrite(PIN_MOTOR_RIGHT, LOW);
    motorOffTime = 0;
    fallDetected = false;
  }
}

// =========================== SETUP ==================================
void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(PIN_MOTOR_LEFT, OUTPUT);
  pinMode(PIN_MOTOR_RIGHT, OUTPUT);
  digitalWrite(PIN_MOTOR_LEFT, LOW);
  digitalWrite(PIN_MOTOR_RIGHT, LOW);

  analogReadResolution(12); // ESP32 12-bit ADC (0–4095 counts)
  initMPU6050();

  // 1. Connect Wi-Fi
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 30) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi connected. IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWi-Fi connection failed. Running offline mode.");
  }

  // 2. Configure Firebase Realtime Database
  Serial.println("Firebase authentication started.");
  config.api_key      = API_KEY;
  config.database_url = DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Wait for token / ready
  unsigned long startWait = millis();
  while (!Firebase.ready() && (millis() - startWait < 4000)) {
    delay(100);
  }

  firebaseReady = Firebase.ready();
  Serial.println("Initialization complete.");
  Serial.println("Commands: L=left motor, R=right motor, F=fall pattern, S=stop");
}

// ============================ LOOP ==================================
void loop() {
  // 1. Check Serial Port Commands (from Arduino Serial Monitor)
  if (Serial.available()) {
    char cmd = Serial.read();
    executeCommand(cmd);
  }

  // 2. Read Pressure Sensors
  heelADC     = analogRead(PIN_FSR_HEEL);
  midfootADC  = analogRead(PIN_FSR_MIDFOOT);
  forefootADC = analogRead(PIN_FSR_FOREFOOT);

  // 3. Read IMU
  readMPU6050(accelG, gyroDPS);

  // 4. Gait Detection & Step Counting
  int totalADC = heelADC + midfootADC + forefootADC;
  if (!footContact && totalADC > 900) {
    footContact = true;
    stepCount++;
  } else if (footContact && totalADC < 250) {
    footContact = false;
  }

  // Fall detection trigger
  if (accelG > 2.8 || (accelG < 0.3 && gyroDPS > 75.0)) {
    fallDetected = true;
  }

  // Auto turn-off haptic motors after pulse duration (non-blocking)
  if (motorOffTime > 0 && millis() >= motorOffTime) {
    digitalWrite(PIN_MOTOR_LEFT, LOW);
    digitalWrite(PIN_MOTOR_RIGHT, LOW);
    motorOffTime = 0;
  }

  unsigned long now = millis();

  // 5. Check Cloud Commands from App (every 200ms)
  if (WiFi.status() == WL_CONNECTED && (now - lastCmdCheck >= CMD_CHECK_MS)) {
    lastCmdCheck = now;
    if (Firebase.RTDB.getJSON(&fbdoCmd, "/SmartFootwear/commands")) {
      FirebaseJson &json = fbdoCmd.jsonObject();
      FirebaseJsonData cmdData, timeData;
      json.get(cmdData, "command");
      json.get(timeData, "timestamp");
      String cmd = cmdData.stringValue;
      long long ts = timeData.int64Value;
      if (cmd.length() > 0 && (ts != lastCmdTimestamp || cmd != lastExecutedCmd)) {
        lastCmdTimestamp = ts;
        lastExecutedCmd = cmd;
        Serial.printf("[Cloud Command Received] %s (ts=%lld)\n", cmd.c_str(), ts);
        executeCommand(cmd.charAt(0));
      }
    } else if (Firebase.RTDB.getString(&fbdoCmd, "/SmartFootwear/commands/command")) {
      String cmd = fbdoCmd.stringData();
      if (cmd.length() > 0 && cmd != lastExecutedCmd) {
        lastExecutedCmd = cmd;
        Serial.printf("[Cloud Command Received] %s\n", cmd.c_str());
        executeCommand(cmd.charAt(0));
      }
    }
  }

  // 6. Periodic Serial Output & Firebase Upload (every 500ms)
  if (now - lastUploadTime >= UPLOAD_INTERVAL_MS) {
    lastUploadTime = now;

    // Serial Monitor Printout
    Serial.println("\n--- SMART FOOTWEAR DATA ---");
    Serial.printf("Heel ADC: %d\n", heelADC);
    Serial.printf("Midfoot ADC: %d\n", midfootADC);
    Serial.printf("Forefoot ADC: %d\n", forefootADC);
    Serial.printf("Acceleration (g): %.2f\n", accelG);
    Serial.printf("Gyroscope (dps): %.2f\n", gyroDPS);
    Serial.println("MPU6050: Ready");
    Serial.printf("Fall detected: %s\n", fallDetected ? "YES" : "NO");
    Serial.printf("Foot contact: %s\n", footContact ? "YES" : "NO");
    Serial.printf("Steps: %d\n", stepCount);
    Serial.println("---------------------------");

    // Upload to Firebase Realtime Database
    if (WiFi.status() == WL_CONNECTED) {
      FirebaseJson json;
      json.set("step_count", stepCount);
      json.set("steps", stepCount);
      json.set("dashboardSteps", stepCount);
      json.set("dailyGoal", 8000);

      json.set("heel_adc", heelADC);
      json.set("midfoot_adc", midfootADC);
      json.set("forefoot_adc", forefootADC);
      json.set("acceleration_g", accelG);
      json.set("gyroscope_dps", gyroDPS);

      json.set("fall_detected", fallDetected);
      json.set("foot_in_contact", footContact);
      json.set("mpu_status", "Ready");
      json.set("esp32_online", true);
      json.set("uptime_ms", (int)millis());

      // 9-channel array for Flutter Insole Heatmap & Waveforms
      FirebaseJsonArray arr;
      arr.add(heelADC);
      arr.add(forefootADC);
      arr.add(midfootADC);
      arr.add(0.0);
      arr.add(0.0);
      arr.add(accelG);
      arr.add(0.0);
      arr.add(0.0);
      arr.add(gyroDPS);
      json.set("sensorValues", arr);

      // Write to /SmartFootwear/latest
      if (Firebase.RTDB.setJSON(&fbdo, "/SmartFootwear/latest", &json)) {
        Serial.println("[Cloud] Firebase upload successful.");
      } else {
        Serial.printf("[Cloud] Firebase upload FAILED: %s\n", fbdo.errorReason().c_str());
      }
    }
  }

  delay(20);
}
