#pragma once
#include <Arduino.h>

#define FSR_HEEL_PIN 34
#define FSR_MIDFOOT_PIN 35
#define FSR_FOREFOOT_PIN 32

struct PressureData {
  int heel;
  int midfoot;
  int forefoot;
};

extern PressureData pressureData;

void initFSRPressure();
void readFSRPressure();
PressureData getPressureData();