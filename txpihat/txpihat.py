# -*- coding: utf-8 -*-

#
#  Python3 class for TxPiHAT control
#  (c) Dr. Till Harbaum, Lars Heuer, Peter Habermehl
#

versionstring = "v2.0 (2025/02/26)"

import RPi.GPIO as GPIO


# board mode uses the pin numbers of the 40 pin connector.
_BOARD_PINS = {"I1": 32, "I2": 36, "I3": 38, "I4": 40,
               "STBY": 35,
               "AIN1": 16, "AIN2": 15, "PWMA": 12,
               "BIN1": 29, "BIN2": 31, "PWMB": 33}

# BCM mode uses the GPIO port numbers
_BCM_PINS = {"I1": 12, "I2": 16, "I3": 20, "I4": 21,
             "STBY": 19,
             "AIN1": 23, "AIN2": 22, "PWMA": 18,
             "BIN1": 5,  "BIN2": 6,  "PWMB": 13}

class TxPiHAT:
    def __init__(self, mode="bcm"):
        self.versionstring = versionstring

        if mode not in {"bcm", "board"}:
            raise ValueError(f"Invalid mode. expected 'board' or 'bcm', got '{mode}'")
        self.mode = mode
        self.pins = _BOARD_PINS if mode == "board" else _BCM_PINS
        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BOARD if mode == "board" else GPIO.BCM)

        # configure I1..I4 as input
        GPIO.setup(self.pins["I1"], GPIO.IN)
        GPIO.setup(self.pins["I2"], GPIO.IN)
        GPIO.setup(self.pins["I3"], GPIO.IN)
        GPIO.setup(self.pins["I4"], GPIO.IN)

        # power up h bridge for M1 and M2
        GPIO.setup(self.pins["STBY"], GPIO.OUT)
        GPIO.output(self.pins["STBY"], GPIO.HIGH)

        # ---------------- M1 -----------------------
        # configure h bridge
        GPIO.setup(self.pins["PWMB"], GPIO.OUT)
        pwm1 = GPIO.PWM(self.pins["PWMB"], 200)  # 200 Hz
        pwm1.start(0)

        GPIO.setup(self.pins["BIN1"], GPIO.OUT)
        GPIO.output(self.pins["BIN1"], GPIO.LOW)

        GPIO.setup(self.pins["BIN2"], GPIO.OUT)
        GPIO.output(self.pins["BIN2"], GPIO.LOW)

        # ---------------- M2 -----------------------
        # configure h bridge
        GPIO.setup(self.pins["PWMA"], GPIO.OUT)
        self.pwm2 = GPIO.PWM(self.pins["PWMA"], 200)  # 200 Hz
        self.pwm2.start(0)

        GPIO.setup(self.pins["AIN1"], GPIO.OUT)
        GPIO.output(self.pins["AIN1"], GPIO.LOW)

        GPIO.setup(self.pins["AIN2"], GPIO.OUT)
        GPIO.output(self.pins["AIN2"], GPIO.LOW)

    def get_input(self, i):
        return GPIO.input(self.pins[i]) != 1

    def m_set_pwm(self, motor, v):
        mpwm = {"M1": self.pwm1, "M2": self.pwm2}
        mpwm[motor].ChangeDutyCycle(v)

    def m_set_mode(self, motor, mode):
        mpins = {"M1": [self.pins["BIN1"], self.pins["BIN2"]],
                 "M2": [self.pins["AIN1"], self.pins["AIN2"]]}
        bits = {"Off":   [GPIO.LOW,  GPIO.LOW],
                "Left":  [GPIO.HIGH, GPIO.LOW],
                "Right": [GPIO.LOW,  GPIO.HIGH],
                "Brake": [GPIO.HIGH, GPIO.HIGH]}
        GPIO.output(mpins[motor][0], bits[mode][0])
        GPIO.output(mpins[motor][1], bits[mode][1])
