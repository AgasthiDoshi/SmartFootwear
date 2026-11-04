/*
 * wifi_navigation.h
 * HTTP Wi-Fi navigation commands from Flutter to ESP32.
 */

#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "haptic_motor.h"

WebServer navigationServer(80);

// Change this to your own private token.
// Use the same token in your Flutter application.
#define DEVICE_TOKEN "CHANGE_THIS_TOKEN"

String lastCommandId = "";

void sendNavigationResponse(int code, String response) {
  navigationServer.sendHeader("Access-Control-Allow-Origin", "*");
  navigationServer.send(code, "application/json", response);
}

bool checkNavigationAuthentication() {
  if (!navigationServer.hasHeader("X-Device-Token")) {
    return false;
  }

  return navigationServer.header("X-Device-Token") ==
         String(DEVICE_TOKEN);
}

void handleNavigationCommand(String maneuver) {

  if (WiFi.status() != WL_CONNECTED) {
    sendNavigationResponse(
      503,
      "{\"success\":false,\"message\":\"WiFi disconnected\"}"
    );
    return;
  }

  if (!checkNavigationAuthentication()) {
    sendNavigationResponse(
      401,
      "{\"success\":false,\"message\":\"Unauthorized\"}"
    );
    return;
  }

  if (!navigationServer.hasArg("command_id")) {
    sendNavigationResponse(
      400,
      "{\"success\":false,\"message\":\"command_id required\"}"
    );
    return;
  }

  String commandId = navigationServer.arg("command_id");

  if (commandId.length() == 0 || commandId.length() > 64) {
    sendNavigationResponse(
      400,
      "{\"success\":false,\"message\":\"Invalid command_id\"}"
    );
    return;
  }

  // Prevent the same navigation instruction from vibrating twice.
  if (commandId == lastCommandId) {
    sendNavigationResponse(
      200,
      "{\"success\":true,\"status\":\"duplicate_ignored\"}"
    );
    return;
  }

  int duration = 350;

  if (navigationServer.hasArg("duration_ms")) {
    duration = navigationServer.arg("duration_ms").toInt();
  }

  duration = constrain(duration, 50, 1500);

  hapticStop();

  if (maneuver == "left" || maneuver == "slight-left") {
    hapticPulseLeft(duration, 220);
  }
  else if (maneuver == "right" || maneuver == "slight-right") {
    hapticPulseRight(duration, 220);
  }
  else if (maneuver == "uturn" ||
           maneuver == "arrived" ||
           maneuver == "off-route") {
    hapticPulseBoth(duration, 220);
  }
  else if (maneuver == "straight" || maneuver == "stop") {
    hapticStop();
  }
  else {
    sendNavigationResponse(
      404,
      "{\"success\":false,\"message\":\"Unknown command\"}"
    );
    return;
  }

  lastCommandId = commandId;

  String response =
    "{\"success\":true,\"command_id\":\"" +
    commandId +
    "\",\"maneuver\":\"" +
    maneuver +
    "\",\"duration_ms\":" +
    String(duration) +
    "}";

  sendNavigationResponse(200, response);
}

void initWifiNavigation() {

  const char* headerKeys[] = {"X-Device-Token"};
  navigationServer.collectHeaders(headerKeys, 1);

  navigationServer.on("/status", HTTP_GET, []() {

    String response = "{\"wifi_connected\":";

    response +=
      (WiFi.status() == WL_CONNECTED) ? "true" : "false";

    response += ",\"ip\":\"";
    response += WiFi.localIP().toString();
    response += "\",\"uptime_ms\":";
    response += String(millis());
    response += "}";

    sendNavigationResponse(200, response);
  });

  navigationServer.on("/navigate/left", HTTP_POST, []() {
    handleNavigationCommand("left");
  });

  navigationServer.on("/navigate/right", HTTP_POST, []() {
    handleNavigationCommand("right");
  });

  navigationServer.on("/navigate/slight-left", HTTP_POST, []() {
    handleNavigationCommand("slight-left");
  });

  navigationServer.on("/navigate/slight-right", HTTP_POST, []() {
    handleNavigationCommand("slight-right");
  });

  navigationServer.on("/navigate/uturn", HTTP_POST, []() {
    handleNavigationCommand("uturn");
  });

  navigationServer.on("/navigate/straight", HTTP_POST, []() {
    handleNavigationCommand("straight");
  });

  navigationServer.on("/navigate/arrived", HTTP_POST, []() {
    handleNavigationCommand("arrived");
  });

  navigationServer.on("/navigate/off-route", HTTP_POST, []() {
    handleNavigationCommand("off-route");
  });

  navigationServer.on("/navigate/stop", HTTP_POST, []() {
    handleNavigationCommand("stop");
  });

  navigationServer.begin();

  Serial.println("[Navigation] HTTP server started.");
  Serial.print("[Navigation] ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

void updateWifiNavigation() {
  navigationServer.handleClient();
}