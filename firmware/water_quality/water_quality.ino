/*
 * HydroCheck ESP32 Firmware
 * Sends pH, Temperature (DS18B20), and TDS data to Firebase Firestore.
 * Displays readings on 16x2 Parallel LCD.
 */
#include <Arduino.h>
#include <DallasTemperature.h>
#include <Firebase_ESP_Client.h>
#include <LiquidCrystal.h>
#include <OneWire.h>
#include <WiFi.h>
#include <WiFiManager.h>

// ---------------------------------------------------------------------------
// 1. CONFIGURATION
// ---------------------------------------------------------------------------
// WiFi is configured via captive portal (no hardcoded credentials)

// Firebase Project Credentials
#define API_KEY " Your API Key Value "
#define USER_EMAIL "mainprojectstc@gmail.com"
#define USER_PASSWORD "mainproject@stc123"
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

// LCD Contrast via PWM (no potentiometer needed)
#define PIN_CONTRAST 26
#define CONTRAST_VALUE 75

// ---------------------------------------------------------------------------
// 2. OBJECTS & GLOBALS
// ---------------------------------------------------------------------------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

OneWire oneWire(PIN_TEMP);
DallasTemperature sensors(&oneWire);

unsigned long sendDataPrevMillis = 0;
unsigned long lastScreenChange = 0;
int currentScreen = 0;

float temperature = 0.0;
float phValue = 7.0;
float tdsValue = 0.0;

// ---------------------------------------------------------------------------
// 3. SETUP
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);

  // Init Contrast
  analogWrite(PIN_CONTRAST, CONTRAST_VALUE);

  // Initialize Sensors
  pinMode(PIN_PH, INPUT);
  pinMode(PIN_TDS, INPUT);
  sensors.begin();

  // Init LCD
  lcd.begin(16, 2);
  lcd.print("HydroCheck v2");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");

  // Connect to WiFi via WiFiManager
  // If no saved WiFi, creates hotspot "HydroCheck-Setup"
  // Connect to it from your phone to configure WiFi
  WiFiManager wm;
  lcd.clear();
  lcd.print("WiFi Setup...");
  lcd.setCursor(0, 1);
  lcd.print("AP:HydroCheck");
  Serial.println("Starting WiFiManager...");

  // autoConnect: tries saved credentials first, if fail -> captive portal
  // Times out after 180 seconds (3 min) and continues offline
  wm.setConfigPortalTimeout(180);
  bool wifiOk = wm.autoConnect("HydroCheck-Setup");

  if (wifiOk) {
    Serial.print("WiFi Connected! IP: ");
    Serial.println(WiFi.localIP());
    lcd.clear();
    lcd.print("WiFi OK!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP());
    delay(2000);
  } else {
    Serial.println("WiFi FAILED - running offline");
    lcd.clear();
    lcd.print("WiFi OFFLINE");
    delay(2000);
  }

  // Firebase Config
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Sync time via NTP (needed for real timestamps)
  configTime(19800, 0, "pool.ntp.org", "time.nist.gov"); // UTC+5:30 = 19800s
  Serial.print("Syncing time");
  int ntpRetry = 0;
  while (time(nullptr) < 100000 && ntpRetry < 20) {
    Serial.print(".");
    delay(500);
    ntpRetry++;
  }
  Serial.println(" Done!");

  lcd.clear();
}

// ---------------------------------------------------------------------------
// 4. MAIN LOOP
// ---------------------------------------------------------------------------
void loop() {
  // --- Read Sensors ---

  // 1. Temperature (DS18B20)
  sensors.requestTemperatures();
  float t = sensors.getTempCByIndex(0);
  if (t == -127.00)
    t = 25.0;
  temperature = t;

  // 2. pH (with voltage divider: pin reads half of sensor voltage)
  int phRaw = analogRead(PIN_PH);
  float phVoltage = phRaw * (3.3 / 4095.0);
  // Neutral (pH 7) = 2.5V from sensor = 1.25V at pin after divider
  phValue = 7.0 + ((1.25 - phVoltage) / 0.18) + 1.5; // +1.5 calibration offset
  phValue = constrain(phValue, 0.0, 14.0);           // Clamp to valid range

  // 3. TDS
  int tdsRaw = analogRead(PIN_TDS);
  float tdsVoltage = tdsRaw * (3.3 / 4095.0);
  tdsValue = (133.42 * tdsVoltage * tdsVoltage * tdsVoltage -
              255.86 * tdsVoltage * tdsVoltage + 857.39 * tdsVoltage) *
             0.5;

  // --- Serial Debug ---
  Serial.printf("Temp: %.1fC | pH: %.2f | TDS: %.0f ppm\n", temperature,
                phValue, tdsValue);

  // --- Send to Firebase every 5 seconds ---
  if (Firebase.ready() &&
      (millis() - sendDataPrevMillis > 5000 || sendDataPrevMillis == 0)) {
    sendDataPrevMillis = millis();

    String readingId = String(millis());
    String documentPath =
        "devices/" + String(DEVICE_ID) + "/readings/reading_" + readingId;

    // Get current time as ISO8601 string
    time_t now = time(nullptr);
    struct tm *timeinfo = gmtime(&now);
    char timeStr[30];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%SZ", timeinfo);

    FirebaseJson content;
    content.set("fields/readingId/stringValue", readingId);
    content.set("fields/deviceId/stringValue", DEVICE_ID);
    content.set("fields/timestamp/timestampValue", timeStr);

    // Parameters Map
    content.set("fields/parameters/mapValue/fields/pH/doubleValue", phValue);
    content.set("fields/parameters/mapValue/fields/temperature/doubleValue",
                temperature);
    content.set("fields/parameters/mapValue/fields/tds/doubleValue", tdsValue);

    // Safety Status
    bool isSafe = (phValue >= 6.5 && phValue <= 8.5 && temperature < 30 &&
                   tdsValue < 500);
    content.set("fields/isSafe/booleanValue", isSafe);

    Serial.print("Sending (pH: ");
    Serial.print(phValue);
    Serial.print(", Temp: ");
    Serial.print(temperature);
    Serial.println(")...");

    if (Firebase.Firestore.createDocument(
            &fbdo, PROJECT_ID, "", documentPath.c_str(), content.raw())) {
      Serial.println("Sent to Firestore!");
    } else {
      Serial.print("Error: ");
      Serial.println(fbdo.errorReason());
    }
  }

  // --- Update LCD (Cycle every 3 seconds) ---
  if (millis() - lastScreenChange > 3000) {
    currentScreen = (currentScreen + 1) % 2;
    lastScreenChange = millis();
    lcd.clear();

    if (currentScreen == 0) {
      // Screen 1: Temp & pH
      lcd.setCursor(0, 0);
      lcd.print("Temp: ");
      lcd.print(temperature, 1);
      lcd.print("C");
      lcd.setCursor(0, 1);
      lcd.print("pH:   ");
      lcd.print(phValue, 1);
    } else {
      // Screen 2: TDS & WiFi Status
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