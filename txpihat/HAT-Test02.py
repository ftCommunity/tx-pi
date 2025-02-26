#! /usr/bin/env python3
# -*- coding: utf-8 -*-

from txpihat import *
from time import sleep
from math import *

# define escape codes for text output
ansi_red = "\033[31m"
ansi_ul = "\033[4m"
ansi_std = "\033[0m" #\033[21m"

ansi_crs_off = "\033[?25l"
ansi_crs_on  = "\033[?25h"

# create HAT object
try:
    hat = TxPiHAT()
except Exception as e: # falls das nicht geklappt hat....
    print(str(e))
    exit()


# print HAT object status

print(ansi_crs_off)
print(ansi_red + ansi_ul + "TxPi Output test" + ansi_std)
print()
print("HAT object:", ansi_red, hat, ansi_std)
print()

# run a sine ramp on both motors, inverted for M2

print(ansi_red + ansi_ul + "Sine ramp simultaneously on both outputs" + ansi_std)
print()

delay = 0.1    # delay between two steps in seconds
x = 0           # counter

hat.m_set_mode("M1","Right")  # set direction for M1 and PWM percentage to zero
hat.m_set_mode("M2","Left")   # set direction for M2 and PWM percentage to zero

print("\n--- Start motors ---")

for x in range(0, 181):
    v = sin(radians(x))*100
    print("Step: {:>3}    Value M1: {:>-4.2f}    Value M2: {:>-4.2f}".format(x,v,-v), "    \033[1A")

    hat.m_set_pwm("M1",abs(v))
    hat.m_set_pwm("M2",abs(v))
    sleep(delay)

# reverse directions
hat.m_set_mode("M1","Left")   # set direction for M1 and PWM percentage to zero
hat.m_set_mode("M2","Right")  # set direction for M2 and PWM percentage to zero

print("\n--- Reverse directions ---")

for x in range(180, 361):
    v = sin(radians(x))*100
    print("Step: {:>3}    Value M1: {:>-4.2f}    Value M2: {:>-4.2f}".format(x,v,-v), "    \033[1A")

    hat.m_set_pwm("M1",abs(v))
    hat.m_set_pwm("M2",abs(v))
    sleep(delay)

# stop motors
hat.m_set_mode("M1","Off")  # set direction for M1 and PWM percentage to zero
hat.m_set_mode("M2","Off")   # set direction for M2 and PWM percentage to zero

print("\n--- Stop motors ---")

print(ansi_red + "\n---End---\n" + ansi_std + ansi_crs_on)
