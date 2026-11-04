#include <Arduino.h>
#include <Wire.h>

#include "fsr_pressure.h"
#include "mpu6050_fall.h"
#include "gait_analysis.h"
#include "haptic_motor.h"
#include "firebase_cloud.h"

// Timing variables
unsigned long lastPrintMs = 0;
unsigned long lastUploadMs = 0;

const unsigned long PRINT_INTERVAL_MS = 1000;
const unsigned long FIREBASE_INTERVAL_MS = 2000;

void printFootwearData();

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("================================");
  Serial.println("       AI SMART FOOTWEAR");
  Serial.println("================================");

  // Initialize I2C
  Wire.begin(21, 22);

  // Initialize sensors and hardware
  Serial.println("[INIT] Initializing FSR sensors...");
  initFSRPressure();

  Serial.println("[INIT] Initializing MPU6050...");
  initMPU6050();

  Serial.println("[INIT] Initializing haptic motors...");
  initHapticMotors();

  // Initialize Firebase and Wi-Fi
  Serial.println("[INIT] Initializing Firebase...");
  initFirebaseCloud();

  Serial.println();
  Serial.println("[SYSTEM] Initialization sequence completed.");
  Serial.println("[SYSTEM] Ready for App Navigation & Serial commands:");
  Serial.println("  L = Left motor");
  Serial.println("  R = Right motor");
  Serial.println("  F = Fall vibration pattern");
  Serial.println("  S = Stop motors");
  Serial.println("================================");
}

void loop() {

  // 1. Read sensors
  readFSRPressure();
  updateMPU6050();

  // 2. Analyze walking and steps
  updateGaitAnalysis();

  // 3. Update motor patterns continuously
  hapticUpdate();

  // 4. Check for Navigation & Motor Commands from Flutter App via Firebase!
  checkFirebaseCloudCommands();

  // 5. Read serial motor commands
  if (Serial.available() > 0) {

    char command = Serial.read();

    switch (command) {

      case 'L':
      case 'l':
        Serial.println("[MOTOR] Left motor activated");
        hapticPulseLeft(350, 220);
        break;

      case 'R':
      case 'r':
        Serial.println("[MOTOR] Right motor activated");
        hapticPulseRight(350, 220);
        break;

      case 'F':
      case 'f':
        Serial.println("[MOTOR] Fall vibration pattern");
        hapticPattern_Fall();
        break;

      case 'S':
      case 's':
        Serial.println("[MOTOR] Motors stopped");
        hapticStop();
        break;

      default:
        break;
    }
  }

  unsigned long now = millis();

  // 6. Print sensor information every second
  if (now - lastPrintMs >= PRINT_INTERVAL_MS) {
    lastPrintMs = now;
    printFootwearData();
  }

  // 7. Upload sensor data every two seconds
  if (now - lastUploadMs >= FIREBASE_INTERVAL_MS) {
    lastUploadMs = now;

    Serial.println("[CLOUD] Uploading footwear data...");
    uploadFootwearData();
  }
}

// ==========================================
// PRINT SENSOR DATA
// ==========================================

void printFootwearData() {

  PressureData p = getPressureData();

  Serial.println();
  Serial.println("-------- SMART FOOTWEAR DATA --------");

  Serial.print("Heel ADC: ");
  Serial.println(p.heel);

  Serial.print("Midfoot ADC: ");
  Serial.println(p.midfoot);

  Serial.print("Forefoot ADC: ");
  Serial.println(p.forefoot);

  Serial.print("Acceleration (g): ");
  Serial.println(getAccelMagnitudeG(), 2);

  Serial.print("Gyroscope (dps): ");
  Serial.println(getGyroMagnitudeDps(), 2);

  Serial.print("MPU6050: ");
  Serial.println(isMPU6050Ready() ? "Ready" : "Not detected");

  Serial.print("Fall detected: ");
  Serial.println(isFallDetected() ? "YES" : "NO");

  Serial.print("Foot contact: ");
  Serial.println(isFootInContact() ? "YES" : "NO");

  Serial.print("Steps: ");
  Serial.println(getStepCount());

  Serial.println("-------------------------------------");
}
