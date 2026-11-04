AI SMART FOOTWEAR — FILE SETUP
==============================

FILES
-----
SmartFootwear.ino
fsr_pressure.h
mpu6050_fall.h
gait_analysis.h
haptic_motor.h
firebase_cloud.h
firebase_cloud.cpp

IMPORTANT ARDUINO IDE NAMING
----------------------------
The .ino and all .h/.cpp files must be in the same sketch folder.
In Arduino IDE, create a sketch named SmartFootwear, then add the support
files as tabs with the exact names above. Keep firebase_cloud.cpp lowercase
as shown.

PIN CONNECTIONS
---------------
FSR heel divider output      -> GPIO34
FSR midfoot divider output   -> GPIO35
FSR forefoot divider output  -> GPIO32
MPU6050 SDA                  -> GPIO21
MPU6050 SCL                  -> GPIO22
Left motor driver input      -> GPIO25 through 1k resistor to transistor base
Right motor driver input     -> GPIO26 through 1k resistor to transistor base
All component grounds        -> common GND

For each FSR divider: 3.3V -> FSR -> ADC junction -> 10k resistor -> GND.
Do not connect a coin motor directly to an ESP32 GPIO. Use transistor/MOSFET
drivers, a suitable motor supply, common ground, and a flyback diode.

LIBRARIES
---------
- Firebase Arduino Client Library for ESP8266 and ESP32 by Mobizt
  (provides Firebase_ESP_Client.h; this legacy library is deprecated upstream)
- No third-party MPU6050 library is required; this project uses raw I2C.
- ESP32 board package for Arduino IDE.

FIREBASE
--------
1. Create/open a Firebase project.
2. Create a Realtime Database and copy its URL.
3. Enable Email/Password under Authentication and create an auth user.
4. Replace all placeholders at the top of firebase_cloud.h:
   WIFI_SSID, WIFI_PASSWORD, FIREBASE_API_KEY, FIREBASE_DATABASE_URL,
   FIREBASE_USER_EMAIL, FIREBASE_USER_PASSWORD.
5. Set Realtime Database rules to allow authenticated access only.
6. Upload and open Serial Monitor at 115200 baud.
7. Data is written to /SmartFootwear/latest every 2 seconds.

SERIAL MOTOR TEST
-----------------
Send one character in Serial Monitor:
l = left motor
r = right motor
f = fall-alert vibration (prototype pattern)
s = stop

NOTES / LIMITATIONS
-------------------
- FSR values are ADC counts, not calibrated pressure/force.
- Contact threshold in gait_analysis.h must be calibrated for your FSRs.
- Fall detection uses a simple freefall + impact heuristic. It may miss falls
  or trigger false positives and is not a safety-certified detector.
- Current Firebase calls are synchronous and can briefly block loop().
- This code uploads sensor data over Wi-Fi; it does not implement phone GPS,
  turn-by-turn routing, or app-to-ESP32 navigation commands yet.
- Do not put real Wi-Fi or Firebase credentials in a public repository.
