/*
 * haptic_motor.h
 * AI Smart Footwear - Navigation Haptic Motor Control
 *
 * LEFT MOTOR  : GPIO 25
 * RIGHT MOTOR : GPIO 26
 */
#pragma once
#include <Arduino.h>

#define HAPTIC_LEFT_PIN  25
#define HAPTIC_RIGHT_PIN 26

void initHapticMotors();
void hapticStop();
void hapticPulseLeft(int durationMs, int intensity = 255);
void hapticPulseRight(int durationMs, int intensity = 255);
void hapticPulseBoth(int durationMs, int intensity = 220);

void hapticPattern_Fall();
void hapticPattern_Left();
void hapticPattern_Right();
void hapticPattern_Arrived();
void hapticPattern_OffRoute();

void hapticUpdate();
bool isLeftMotorOn();
bool isRightMotorOn();
bool areHapticMotorsOn();
