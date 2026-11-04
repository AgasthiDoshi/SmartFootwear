/*
 * gait_analysis.h
 * Simple pressure-based contact, stance and step count estimate.
 */
#pragma once
#include <Arduino.h>

#define FSR_CONTACT_THRESHOLD 250

void updateGaitAnalysis();
bool isFootInContact();
unsigned long getStepCount();
unsigned long getContactChangeMs();
