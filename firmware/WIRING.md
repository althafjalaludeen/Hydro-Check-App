# HydroCheck Hardware Wiring Guide (Parallel LCD)

## Components
1.  **ESP32 Development Board** (e.g., ESP32 DevKit V1)
2.  **DS18B20** Temperature Sensor Probe
3.  **TDS Sensor** (Analog)
4.  **Turbidity Sensor** (Analog)
5.  **Industrial pH Sensor V3.0** (Analog)
6.  **16x2 LCD (JHD162A)** - Parallel Mode
7.  **Potentiometer (10k)** - For LCD Contrast
8.  **Resistors**: 4.7kΩ (for DS18B20), 2x 4.7kΩ or 10kΩ (voltage dividers)

## Pinout Table

### 16x2 LCD (Parallel 4-bit Mode)
| LCD Pin | Function | Connect To | Notes |
| :--- | :--- | :--- | :--- |
| **1 (VSS)** | Ground | GND | |
| **2 (VDD)** | Power | VIN (5V) | LCD needs 5V |
| **3 (V0)** | Contrast | GPIO 26 | Software PWM contrast (no pot needed) |
| **4 (RS)** | Register Select | GPIO 18 | |
| **5 (RW)** | Read/Write | GND | Write mode only |
| **6 (E)** | Enable | GPIO 19 | |
| **7-10** | D0-D3 | (Not Connected) | |
| **11 (D4)** | Data 4 | GPIO 21 | |
| **12 (D5)** | Data 5 | GPIO 22 | |
| **13 (D6)** | Data 6 | GPIO 23 | |
| **14 (D7)** | Data 7 | GPIO 25 | |
| **15 (A)** | Backlight + | 5V | |
| **16 (K)** | Backlight - | GND | |

### Sensors
| Component | Pin Label | ESP32 Pin | Notes |
| :--- | :--- | :--- | :--- |
| **DS18B20 Temp** | VCC | 3V3 | |
| | GND | GND | |
| | DATA | GPIO 4 | Add 4.7k resistor between DATA and 3V3 |
| **TDS Sensor** | VCC | 3V3 | |
| | GND | GND | |
| | Signal | GPIO 34 | Analog Input (No divider needed) |
| **Turbidity** | VCC | 5V | |
| | GND | GND | |
| | Signal | GPIO 35 | **Voltage Divider REQUIRED** (See Note 3) |
| **Industrial pH V3.0** | VCC | 5V | "Bharath" Industrial Module |
| | GND | GND | |
| | Signal | GPIO 32 | **Voltage Divider RECOMMENDED** (See Note 4) |

## Important Notes
1.  **LCD Voltage**: The LCD logic is 5V. ESP32 outputs 3.3V. Direct connection usually works. If blank, you may need a level shifter.
2.  **Contrast**: You **MUST** connect Pin 3 (V0) to a potentiometer. Without it, text will be invisible.
3.  **Turbidity Voltage Divider**: Output can reach **4.5V**. ESP32 max is **3.3V**. Use two equal resistors (4.7kΩ or 10kΩ) as a voltage divider on GPIO 35. Code multiplies reading by 2.
4.  **pH Sensor Voltage Divider**: Output can reach **5V**. Use the same divider (two 4.7kΩ resistors) on GPIO 32. Code multiplies reading by 2.
5.  **TDS Sensor**: Output is **0-2.3V**. Safe for ESP32. **No divider needed.**
6.  **pH Calibration**: The pH formula in code is approximate. Calibrate with buffer solutions (pH 4.0 and 7.0) and adjust the formula in `loop()`.
