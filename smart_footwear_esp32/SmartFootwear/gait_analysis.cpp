/*
 * gait_analysis.cpp
 * Shared implementation for pressure-based gait and step counting.
 */
#include "gait_analysis.h"
#include "fsr_pressure.h"

static bool footInContact = false;
static unsigned long lastContactChangeMs = 0;
static unsigned long stepCount = 0;
static bool previousFootInContact = false;

void updateGaitAnalysis() {
  PressureData p = getPressureData();
  bool contact = (p.heel > FSR_CONTACT_THRESHOLD ||
                  p.midfoot > FSR_CONTACT_THRESHOLD ||
                  p.forefoot > FSR_CONTACT_THRESHOLD);

  unsigned long now = millis();
  if (contact != previousFootInContact) {
    lastContactChangeMs = now;
    if (contact && !previousFootInContact) {
      stepCount++;
    }
    previousFootInContact = contact;
  }
  footInContact = contact;
}

bool isFootInContact() {
  return footInContact;
}

unsigned long getStepCount() {
  return stepCount;
}

unsigned long getContactChangeMs() {
  return lastContactChangeMs;
}

