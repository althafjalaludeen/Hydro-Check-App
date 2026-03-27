/*
 * HydroCheck ESP32 Firmware
 * Sends pH, Temperature (DS18B20), and TDS data to Firebase Firestore.
 * Uses direct HTTPS REST API calls - NO Firebase library needed!
 * Displays readings on 16x2 Parallel LCD.
 */

#include <Arduino.h>
#include <DallasTemperature.h>
#include <HTTPClient.h>
#include <LiquidCrystal.h>
#include <OneWire.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiManager.h>
#include <ArduinoJson.h>

// ---------------------------------------------------------------------------
// 1. CONFIGURATION
// ---------------------------------------------------------------------------

// Firebase Project Credentials
#define API_KEY " Your API Key Value "
#define USER_EMAIL "mainprojectstc@gmail.com"
#define USER_PASSWORD "Althaf@123"
#define PROJECT_ID "hydrocheck-e882a"

// Device Info
#define DEVICE_ID "device_001"

// Sensor Pins
#define PIN_PH 33  // Analog Pin for pH Sensor
#define PIN_TDS 34 // Analog Pin for TDS Sensor
#define PIN_TEMP 4 // Digital Pin for DS18B20

// LCD (Parallel 4-bit Mode)
const int rs = 18, en = 19, d4 = 21, d5 = 22, d6 = 23, d7 = 25;
LiquidCrystal lcd(rs, en, d4, d5, d6, d7);

// LCD Contrast via PWM
#define PIN_CONTRAST 26
#define CONTRAST_VALUE 75

// ---------------------------------------------------------------------------
// 2. OBJECTS & GLOBALS
// ---------------------------------------------------------------------------

OneWire oneWire(PIN_TEMP);
DallasTemperature sensors(&oneWire);
Preferences preferences;

// Timing variables
unsigned long sendDataPrevMillis = 0;
unsigned long lastScreenChange = 0;
int currentScreen = 0;

// Sensor Readings
float phValue = 7.0;
float temperature = 25.0;
float tdsValue = 0.0;

bool wifiOk = false;

// Firebase Auth Token (obtained via REST API)
String firebaseIdToken = "";
unsigned long tokenExpiry = 0;

// ---------------------------------------------------------------------------
// 3. FIREBASE AUTH VIA REST API
// ---------------------------------------------------------------------------
bool firebaseSignIn() {
  Serial.println("Authenticating with Firebase...");

  WiFiClientSecure client;
  client.setInsecure(); // Skip SSL cert verification (saves RAM)

  HTTPClient http;
  String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + String(API_KEY);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  // Build auth request
  String authPayload = "{\"email\":\"" + String(USER_EMAIL) +
                        "\",\"password\":\"" + String(USER_PASSWORD) +
                        "\",\"returnSecureToken\":true}";

  int httpCode = http.POST(authPayload);
  Serial.printf("Auth HTTP code: %d\n", httpCode);

  if (httpCode == 200) {
    String response = http.getString();

    // Parse the ID token from response
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, response);

    if (!error) {
      firebaseIdToken = doc["idToken"].as<String>();
      int expiresIn = doc["expiresIn"].as<String>().toInt();
      tokenExpiry = millis() + (expiresIn * 1000UL) - 60000; // Refresh 1 min early
      Serial.println("Firebase Auth OK! Token received.");
      http.end();
      return true;
    } else {
      Serial.println("JSON parse error on auth response!");
    }
  } else {
    String response = http.getString();
    Serial.println("Auth FAILED: " + response);
  }

  http.end();
  return false;
}

// ---------------------------------------------------------------------------
// 4. SEND DATA TO FIRESTORE VIA REST API
// ---------------------------------------------------------------------------
bool sendToFirestore(float ph, float temp, float tds, bool isSafe, const char* timeStr) {
  // Refresh token if expired
  if (millis() > tokenExpiry || firebaseIdToken.length() == 0) {
    if (!firebaseSignIn()) {
      Serial.println("Token refresh failed, skipping send.");
      return false;
    }
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;

  // Firestore REST endpoint:
  // POST https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/{collection}
  String readingId = String(millis());
  String url = "https://firestore.googleapis.com/v1/projects/" + String(PROJECT_ID) +
               "/databases/(default)/documents/devices/" + String(DEVICE_ID) +
               "/readings?documentId=reading_" + readingId;

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + firebaseIdToken);

  // Build Firestore document JSON
  String payload = "{\"fields\":{";
  payload += "\"readingId\":{\"stringValue\":\"" + readingId + "\"},";
  payload += "\"deviceId\":{\"stringValue\":\"" + String(DEVICE_ID) + "\"},";
  payload += "\"timestamp\":{\"timestampValue\":\"" + String(timeStr) + "\"},";
  payload += "\"isSafe\":{\"booleanValue\":" + String(isSafe ? "true" : "false") + "},";
  payload += "\"parameters\":{\"mapValue\":{\"fields\":{";
  payload += "\"pH\":{\"doubleValue\":" + String(ph, 2) + "},";
  payload += "\"temperature\":{\"doubleValue\":" + String(temp, 2) + "},";
  payload += "\"tds\":{\"doubleValue\":" + String(tds, 0) + "}";
  payload += "}}}";
  payload += "}}";

  int httpCode = http.POST(payload);
  String response = http.getString();
  http.end();

  if (httpCode == 200) {
    Serial.println("Firestore OK!");
    return true;
  } else {
    Serial.printf("Firestore FAILED (HTTP %d): ", httpCode);
    Serial.println(response.substring(0, 200)); // Print first 200 chars of error
    return false;
  }
}

// ---------------------------------------------------------------------------
// 5. SETUP
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);

  // --- Initialize LCD ---
  pinMode(PIN_CONTRAST, OUTPUT);
  analogWrite(PIN_CONTRAST, CONTRAST_VALUE);
  lcd.begin(16, 2);
  lcd.clear();
  lcd.print("HydroCheck Init");
  delay(1000);

  // --- Initialize Sensors ---
  sensors.begin();
  pinMode(PIN_PH, INPUT);
  pinMode(PIN_TDS, INPUT);

  // --- WiFi Connection ---
  lcd.clear();
  lcd.print("Connecting WiFi.");
  Serial.println("Attempting native WiFi connection...");
  WiFi.mode(WIFI_STA);

  preferences.begin("wifi", false);
  String savedSSID = preferences.getString("ssid", "");
  String savedPSK = preferences.getString("password", "");

  if (savedSSID.length() > 0) {
    Serial.printf("Found saved network: %s\n", savedSSID.c_str());
    WiFi.begin(savedSSID.c_str(), savedPSK.c_str());
  } else {
    Serial.println("No saved network found.");
    WiFi.begin();
  }

  int nativeRetries = 0;
  while (WiFi.status() != WL_CONNECTED && nativeRetries < 30) {
    Serial.print(".");
    delay(500);
    nativeRetries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiOk = true;
    Serial.printf("\nWiFi Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    lcd.clear();
    lcd.print("WiFi Connected!");
    delay(1000);
  } else {
    Serial.println("\nWiFi failed. Starting Captive Portal...");
    lcd.clear();
    lcd.print("WiFi Failed!");
    lcd.setCursor(0, 1);
    lcd.print("Connect to AP...");

    WiFiManager wm;
    wm.setConfigPortalTimeout(180);

    if (wm.startConfigPortal("HydroCheck-Setup")) {
      wifiOk = true;
      preferences.putString("ssid", wm.getWiFiSSID());
      preferences.putString("password", wm.getWiFiPass());

      lcd.clear();
      lcd.print("WiFi Saved!");
      lcd.setCursor(0, 1);
      lcd.print("Restarting...");
      delay(2000);
      ESP.restart();
    } else {
      Serial.println("Captive Portal timed out - running offline");
      lcd.clear();
      lcd.print("WiFi OFFLINE");
      delay(2000);
      wifiOk = false;
    }
  }
  preferences.end();

  // --- Sync NTP time ---
  if (wifiOk) {
    lcd.clear();
    lcd.print("Syncing time...");
    configTime(19800, 0, "time.google.com", "pool.ntp.org");
    Serial.print("Syncing NTP time");
    int ntpRetry = 0;
    while (time(nullptr) < 100000 && ntpRetry < 10) {
      Serial.print(".");
      delay(500);
      ntpRetry++;
    }
    if (time(nullptr) >= 100000) {
      Serial.println(" NTP OK!");
      lcd.setCursor(0, 1);
      lcd.print("Time synced!");
    } else {
      Serial.println(" NTP FAILED - using fallback");
      struct timeval tv = {1773936000, 0};
      settimeofday(&tv, NULL);
    }
    delay(500);

    // --- Firebase Sign In ---
    lcd.clear();
    lcd.print("Firebase Auth...");
    if (firebaseSignIn()) {
      lcd.clear();
      lcd.print("Firebase OK!");
      delay(1000);
    } else {
      lcd.clear();
      lcd.print("Auth FAILED");
      lcd.setCursor(0, 1);
      lcd.print("Will retry...");
      delay(1500);
    }
  }

  lcd.clear();
}

// ---------------------------------------------------------------------------
// 6. MAIN LOOP
// ---------------------------------------------------------------------------
void loop() {

  // --- Read Sensors ---

  // 1. Temperature (DS18B20)
  sensors.requestTemperatures();
  float t = sensors.getTempCByIndex(0);
  if (t == -127.00) t = 25.0;
  temperature = t;

  // 2. pH
  int phRaw = analogRead(PIN_PH);
  float phVoltage = phRaw * (3.3 / 4095.0);
  phValue = 7.0 + ((1.25 - phVoltage) / 0.18) + 1.5;
  phValue = constrain(phValue, 0.0, 14.0);

  // 3. TDS
  int tdsRaw = analogRead(PIN_TDS);
  float tdsVoltage = tdsRaw * (3.3 / 4095.0);
  tdsValue = (133.42 * tdsVoltage * tdsVoltage * tdsVoltage -
              255.86 * tdsVoltage * tdsVoltage + 857.39 * tdsVoltage) * 0.5;

  // --- Serial Debug ---
  Serial.printf("Temp: %.1fC | pH: %.2f | TDS: %.0f ppm\n", temperature, phValue, tdsValue);

  // --- Send to Firebase every 5 seconds ---
  if (wifiOk && WiFi.status() == WL_CONNECTED &&
      (millis() - sendDataPrevMillis > 5000 || sendDataPrevMillis == 0)) {
    sendDataPrevMillis = millis();

    // Get current time as ISO8601 string
    time_t now = time(nullptr);
    struct tm* timeinfo = gmtime(&now);
    char timeStr[30];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%SZ", timeinfo);

    bool isSafe = (phValue >= 6.5 && phValue <= 8.5 && temperature < 30 && tdsValue < 500);

    sendToFirestore(phValue, temperature, tdsValue, isSafe, timeStr);
  }

  // --- Update LCD (Cycle every 3 seconds) ---
  if (millis() - lastScreenChange > 3000) {
    currentScreen = (currentScreen + 1) % 2;
    lastScreenChange = millis();
    lcd.clear();

    if (currentScreen == 0) {
      lcd.setCursor(0, 0);
      lcd.print("Temp: ");
      lcd.print(temperature, 1);
      lcd.print("C");
      lcd.setCursor(0, 1);
      lcd.print("pH:   ");
      lcd.print(phValue, 1);
    } else {
      lcd.setCursor(0, 0);
      lcd.print("TDS: ");
      lcd.print((int)tdsValue);
      lcd.print(" ppm");
      lcd.setCursor(0, 1);
      if (WiFi.status() == WL_CONNECTED) {
        lcd.print("WiFi: OK");
      } else {
        lcd.print("WiFi: OFFLINE");
      }
    }
  }

  delay(500);
}