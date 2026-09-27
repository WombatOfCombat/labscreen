#include <Wire.h>
#include <LiquidCrystal_I2C.h>
//DESCRIPTION=============================================================================================
// Part of the labscreen addon.
// Awaits formatted messages over serial link with lcd-stats.sh automatically started by lcd-stats.service
// May interfere with communication over BAUD (line 12) beginning with the key phrases "IP:" and "ST:"
//END DESCRIPTION=========================================================================================

//CONFIG==========================================================================================
//16x2 I2C LCD
LiquidCrystal_I2C lcd(0x27, 16, 2); //TROUBLESHOOTING RELEVANT: try 0x3F if display shows nought
const unsigned long DATA_TIMEOUT_MS = 15000; //time of no contact after which link lost is assumed
const int BAUD = 9600; // if you intend to change BAUD also change it in lcd-stats.sh line 9
//END CONFIG======================================================================================

unsigned long lastUpdateTime = 0;
bool stale = false;

void setup() {
  Serial.begin(BAUD);
  Serial.setTimeout(100);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Waiting for");
  lcd.setCursor(0, 1);
  lcd.print("lcd-stats...");
  //TROUBLESHOOTING RELEVANT: if display shows this message try:
  //1. check if lcd-stats.service is running -> systemctl status lcd-stats.service
  //2. check if you set up your arduino stable path correctly in lcd-stats.sh lines 7-9
  //3. check if the serial port signal is being received -> minicom -D </device/path (usually /dev/ttyACM0)>
}

void printLine(int row, String text) {
  while (text.length() < 16) text += ' ';
  if (text.length() > 16) text = text.substring(0, 16);
  lcd.setCursor(0, row);
  lcd.print(text);
}

void loop() {
  if (Serial.available()) {
    String incoming = Serial.readStringUntil('\n');
    incoming.trim();

    if (incoming.startsWith("IP:")) {
      // Line 1: "XXX.XXX.XXX.XXX" (device IPv4)
      printLine(0, incoming.substring(3));
      lastUpdateTime = millis();
      stale = false;
    } else if (incoming.startsWith("ST:")) {
      // Line 2: "CPU:XXX%RAM:XXX% (device CPU and RAM load)"
      printLine(1, incoming.substring(3));
      lastUpdateTime = millis();
      stale = false;
    }
  }

  //notify of no link activity over BAUD (line 12)
  //TROUBLESHOOTING RELEVANT: lines 29-32
  if (!stale && lastUpdateTime > 0 && millis() - lastUpdateTime > DATA_TIMEOUT_MS) {
    stale = true;
    printLine(1, "link lost");
  }
}
