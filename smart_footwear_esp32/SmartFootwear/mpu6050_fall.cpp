/*
 * mpu6050_fall.cpp
 * Shared implementation for MPU-6050 6-axis IMU reading and fall detection.
 */
#include "mpu6050_fall.h"
#include <Wire.h>
#include <math.h>

#define MPU6050_ADDR 0x68

static int16_t axRaw = 0, ayRaw = 0, azRaw = 0;
static int16_t gxRaw = 0, gyRaw = 0, gzRaw = 0;
static float axG = 0.0f, ayG = 0.0f, azG = 1.0f;
static float gxDps = 0.0f, gyDps = 0.0f, gzDps = 0.0f;
static float accelMagnitudeG = 1.0f;
static float gyroMagnitudeDps = 0.0f;
static bool mpuReady = false;
static bool fallDetected = false;
static bool inFreefall = false;
static unsigned long freefallStartMs = 0;
static unsigned long fallClearMs = 0;

static const float FREEFALL_THRESHOLD_G = 0.40f;
static const float IMPACT_THRESHOLD_G = 2.50f;
static const unsigned long FREEFALL_MIN_MS = 80;
static const unsigned long FALL_CLEAR_MS = 3000;

static bool mpuWriteRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission(true) == 0;
}

void initMPU6050() {
  Serial.print("[MPU6050] Initializing sensor at 0x68... ");

  // Wake up MPU6050 (clear SLEEP bit in PWR_MGMT_1)
  if (!mpuWriteRegister(0x6B, 0x00)) {
    Serial.println("FAILED! Check I2C SDA=GPIO21, SCL=GPIO22, VCC=3.3V.");
    mpuReady = false;
    return;
  }

  // Accelerometer config: ±4g (range: 0x08, sensitivity: 8192 LSB/g)
  mpuWriteRegister(0x1C, 0x08);
  // Gyroscope config: ±500 deg/s (range: 0x08, sensitivity: 65.5 LSB/(deg/s))
  mpuWriteRegister(0x1B, 0x08);
  // DLPF (Digital Low Pass Filter) ~44 Hz bandwidth
  mpuWriteRegister(0x1A, 0x03);

  mpuReady = true;
  Serial.println("SUCCESS (Ready).");
}

static bool readMPU6050Raw() {
  if (!mpuReady) return false;

  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B); // Starting register for Accel X High
  if (Wire.endTransmission(false) != 0) return false;

  uint8_t count = Wire.requestFrom(MPU6050_ADDR, (uint8_t)14, (uint8_t)true);
  if (count != 14) return false;

  axRaw = (int16_t)((Wire.read() << 8) | Wire.read());
  ayRaw = (int16_t)((Wire.read() << 8) | Wire.read());
  azRaw = (int16_t)((Wire.read() << 8) | Wire.read());
  Wire.read(); Wire.read(); // temperature registers (skip)
  gxRaw = (int16_t)((Wire.read() << 8) | Wire.read());
  gyRaw = (int16_t)((Wire.read() << 8) | Wire.read());
  gzRaw = (int16_t)((Wire.read() << 8) | Wire.read());

  // ±4g -> 8192 LSB/g
  axG = axRaw / 8192.0f;
  ayG = ayRaw / 8192.0f;
  azG = azRaw / 8192.0f;

  accelMagnitudeG = sqrtf(axG * axG + ayG * ayG + azG * azG);

  // ±500 dps -> 65.5 LSB/(deg/s)
  gxDps = gxRaw / 65.5f;
  gyDps = gyRaw / 65.5f;
  gzDps = gzRaw / 65.5f;
  gyroMagnitudeDps = sqrtf(gxDps * gxDps + gyDps * gyDps + gzDps * gzDps);

  return true;
}

void updateMPU6050() {
  if (!readMPU6050Raw()) return;

  unsigned long now = millis();

  // Auto-clear fall alert after timeout
  if (fallDetected && now - fallClearMs > FALL_CLEAR_MS) {
    fallDetected = false;
  }

  // Detect freefall (near weightlessness)
  if (!inFreefall && accelMagnitudeG < FREEFALL_THRESHOLD_G) {
    inFreefall = true;
    freefallStartMs = now;
  }

  // Detect subsequent high impact
  if (inFreefall) {
    if (accelMagnitudeG > IMPACT_THRESHOLD_G &&
        now - freefallStartMs >= FREEFALL_MIN_MS) {
      fallDetected = true;
      fallClearMs = now;
      inFreefall = false;
    } else if (accelMagnitudeG >= FREEFALL_THRESHOLD_G &&
               accelMagnitudeG <= IMPACT_THRESHOLD_G &&
               now - freefallStartMs > 500) {
      inFreefall = false;
    }
  }
}

bool isMPU6050Ready() { return mpuReady; }
bool isFallDetected() { return fallDetected; }
float getAccelMagnitudeG() { return accelMagnitudeG; }
float getGyroMagnitudeDps() { return gyroMagnitudeDps; }

float getAxG() { return axG; }
float getAyG() { return ayG; }
float getAzG() { return azG; }
float getGxDps() { return gxDps; }
float getGyDps() { return gyDps; }
float getGzDps() { return gzDps; }

