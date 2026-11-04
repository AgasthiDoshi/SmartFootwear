/*
 * haptic_motor.cpp
 * Shared implementation for Haptic Motor Control (GPIO 25 & 26).
 */
#include "haptic_motor.h"

#define HAPTIC_FREQUENCY 1000
#define HAPTIC_RESOLUTION 8

#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  // ESP32 Arduino Core 3.x
  #define HAPTIC_ATTACH(pin) ledcAttach(pin, HAPTIC_FREQUENCY, HAPTIC_RESOLUTION)
  #define HAPTIC_WRITE(pin, duty) ledcWrite(pin, duty)
#else
  // ESP32 Arduino Core 2.x
  #define HAPTIC_LEFT_CH  4
  #define HAPTIC_RIGHT_CH 5
  #define HAPTIC_ATTACH_LEFT() do { \
      ledcSetup(HAPTIC_LEFT_CH, HAPTIC_FREQUENCY, HAPTIC_RESOLUTION); \
      ledcAttachPin(HAPTIC_LEFT_PIN, HAPTIC_LEFT_CH); \
    } while (0)
  #define HAPTIC_ATTACH_RIGHT() do { \
      ledcSetup(HAPTIC_RIGHT_CH, HAPTIC_FREQUENCY, HAPTIC_RESOLUTION); \
      ledcAttachPin(HAPTIC_RIGHT_PIN, HAPTIC_RIGHT_CH); \
    } while (0)
  #define HAPTIC_WRITE_LEFT(duty) ledcWrite(HAPTIC_LEFT_CH, duty)
  #define HAPTIC_WRITE_RIGHT(duty) ledcWrite(HAPTIC_RIGHT_CH, duty)
#endif

static bool leftOn = false;
static bool rightOn = false;
static unsigned long leftDeadline = 0;
static unsigned long rightDeadline = 0;

void initHapticMotors() {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  HAPTIC_ATTACH(HAPTIC_LEFT_PIN);
  HAPTIC_ATTACH(HAPTIC_RIGHT_PIN);
  HAPTIC_WRITE(HAPTIC_LEFT_PIN, 0);
  HAPTIC_WRITE(HAPTIC_RIGHT_PIN, 0);
#else
  HAPTIC_ATTACH_LEFT();
  HAPTIC_ATTACH_RIGHT();
  HAPTIC_WRITE_LEFT(0);
  HAPTIC_WRITE_RIGHT(0);
#endif

  leftOn = false;
  rightOn = false;

  Serial.println("[HAPTIC] Motors initialized (Left: GPIO 25, Right: GPIO 26).");
}

void hapticStop() {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  HAPTIC_WRITE(HAPTIC_LEFT_PIN, 0);
  HAPTIC_WRITE(HAPTIC_RIGHT_PIN, 0);
#else
  HAPTIC_WRITE_LEFT(0);
  HAPTIC_WRITE_RIGHT(0);
#endif

  leftOn = false;
  rightOn = false;
  leftDeadline = 0;
  rightDeadline = 0;
}

void hapticPulseLeft(int durationMs, int intensity) {
  intensity = constrain(intensity, 0, 255);
  durationMs = constrain(durationMs, 0, 5000);

  if (durationMs == 0 || intensity == 0) {
    hapticStop();
    return;
  }

  hapticStop();

#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  HAPTIC_WRITE(HAPTIC_LEFT_PIN, intensity);
#else
  HAPTIC_WRITE_LEFT(intensity);
#endif

  leftOn = true;
  rightOn = false;
  leftDeadline = millis() + (unsigned long)durationMs;
  Serial.println("[HAPTIC] LEFT motor activated.");
}

void hapticPulseRight(int durationMs, int intensity) {
  intensity = constrain(intensity, 0, 255);
  durationMs = constrain(durationMs, 0, 5000);

  if (durationMs == 0 || intensity == 0) {
    hapticStop();
    return;
  }

  hapticStop();

#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  HAPTIC_WRITE(HAPTIC_RIGHT_PIN, intensity);
#else
  HAPTIC_WRITE_RIGHT(intensity);
#endif

  leftOn = false;
  rightOn = true;
  rightDeadline = millis() + (unsigned long)durationMs;
  Serial.println("[HAPTIC] RIGHT motor activated.");
}

void hapticPulseBoth(int durationMs, int intensity) {
  intensity = constrain(intensity, 0, 255);
  durationMs = constrain(durationMs, 0, 5000);

  if (durationMs == 0 || intensity == 0) {
    hapticStop();
    return;
  }

  hapticStop();

#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  HAPTIC_WRITE(HAPTIC_LEFT_PIN, intensity);
  HAPTIC_WRITE(HAPTIC_RIGHT_PIN, intensity);
#else
  HAPTIC_WRITE_LEFT(intensity);
  HAPTIC_WRITE_RIGHT(intensity);
#endif

  leftOn = true;
  rightOn = true;
  leftDeadline = millis() + (unsigned long)durationMs;
  rightDeadline = millis() + (unsigned long)durationMs;
  Serial.println("[HAPTIC] BOTH motors activated.");
}

void hapticPattern_Fall() {
  hapticPulseBoth(700, 255);
  Serial.println("[HAPTIC] FALL ALERT vibration triggered!");
}

void hapticPattern_Left() {
  hapticPulseLeft(350, 220);
}

void hapticPattern_Right() {
  hapticPulseRight(350, 220);
}

void hapticPattern_Arrived() {
  hapticPulseBoth(500, 220);
}

void hapticPattern_OffRoute() {
  hapticPulseBoth(800, 255);
}

void hapticUpdate() {
  unsigned long now = millis();

  if (leftOn && (long)(now - leftDeadline) >= 0) {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
    HAPTIC_WRITE(HAPTIC_LEFT_PIN, 0);
#else
    HAPTIC_WRITE_LEFT(0);
#endif
    leftOn = false;
  }

  if (rightOn && (long)(now - rightDeadline) >= 0) {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
    HAPTIC_WRITE(HAPTIC_RIGHT_PIN, 0);
#else
    HAPTIC_WRITE_RIGHT(0);
#endif
    rightOn = false;
  }
}

bool isLeftMotorOn() { return leftOn; }
bool isRightMotorOn() { return rightOn; }
bool areHapticMotorsOn() { return leftOn || rightOn; }

