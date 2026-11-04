/*
 * firebase_cloud.h
 * Wi-Fi + Firebase Realtime Database uploads.
 *
 * Library: Firebase Arduino Client Library for ESP8266 and ESP32 by Mobizt
 * (Firebase_ESP_Client.h).
 */
#pragma once
#include <Arduino.h>

#define WIFI_SSID       "OnePlus_24"
#define WIFI_PASSWORD   "k6djpq9f"

#define FIREBASE_API_KEY "AIzaSyCV-3xh_NhxhCz6udfz1BKhc2baY0pGq2o"
#define FIREBASE_DATABASE_URL "https://smartfootwear-6d1a6-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define FIREBASE_USER_EMAIL "agasthidoshi@gmail.com"
#define FIREBASE_USER_PASSWORD "Swami@2408"

void initFirebaseCloud();
bool uploadFootwearData();
void checkFirebaseCloudCommands();
bool isFirebaseConnected();
