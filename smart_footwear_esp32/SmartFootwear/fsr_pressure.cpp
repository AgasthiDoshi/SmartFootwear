
#include "fsr_pressure.h"

PressureData pressureData = {0, 0, 0};

void initFSRPressure() {
  Serial.print("Initializing 3 FSR402 sensors... ");

  analogReadResolution(12);

  analogSetPinAttenuation(FSR_HEEL_PIN, ADC_11db);
  analogSetPinAttenuation(FSR_MIDFOOT_PIN, ADC_11db);
  analogSetPinAttenuation(FSR_FOREFOOT_PIN, ADC_11db);

  pinMode(FSR_HEEL_PIN, INPUT);
  pinMode(FSR_MIDFOOT_PIN, INPUT);
  pinMode(FSR_FOREFOOT_PIN, INPUT);

  Serial.println("OK");
}

void readFSRPressure() {
  const int n = 8;

  long heelSum = 0;
  long midSum = 0;
  long foreSum = 0;

  for (int i = 0; i < n; i++) {
    heelSum += analogRead(FSR_HEEL_PIN);
    midSum += analogRead(FSR_MIDFOOT_PIN);
    foreSum += analogRead(FSR_FOREFOOT_PIN);
  }

  pressureData.heel = heelSum / n;
  pressureData.midfoot = midSum / n;
  pressureData.forefoot = foreSum / n;
}

PressureData getPressureData() {
  return pressureData;
}
