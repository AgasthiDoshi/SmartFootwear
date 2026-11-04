/*
 * mpu6050_fall.h
 * MPU6050 raw-I2C acceleration magnitude, gyroscope, and fall detection.
 * Wiring: SDA -> GPIO21, SCL -> GPIO22, VCC -> 3.3V, GND -> GND.
 */
#pragma once
#include <Arduino.h>

void initMPU6050();
void updateMPU6050();

bool isMPU6050Ready();
bool isFallDetected();
float getAccelMagnitudeG();
float getGyroMagnitudeDps();

// Axis values
float getAxG();
float getAyG();
float getAzG();
float getGxDps();
float getGyDps();
float getGzDps();
