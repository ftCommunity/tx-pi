#! /usr/bin/env python3
# -*- coding: utf-8 -*-

from txpihat import *#
from time import sleep
from math import *

# define escape codes for text output
ansi_red = "\033[31m"
ansi_ul = "\033[4m"
ansi_std = "\033[0m" #\033[21m"

ansi_crs_off = "\033[?25l"
ansi_crs_on  = "\033[?25h"

delay = 0.1 # delay time

# create HAT object
try:
    hat = TxPiHAT()
except Exception as e: # falls das nicht geklappt hat....
    print(str(e))
    exit()

# print HAT object status

print(ansi_crs_off)
print(ansi_red + ansi_ul + "TxPi Input test" + ansi_std)
print()
print("HAT object:", ansi_red, hat, ansi_std)
print()

# Input monitor

print(ansi_red + ansi_ul + "Monitoring all inputs. [Ctrl-C] to stop." + ansi_std)
print()

# infinite loop

try:
    while True:
        print(ansi_red + "I1: " + ansi_std, hat.get_input("I1"), ansi_red + "    I2: " + ansi_std, hat.get_input("I2"))
        print(ansi_red + "I3: " + ansi_std, hat.get_input("I3"), ansi_red + "    I4: " + ansi_std, hat.get_input("I4"))
        print("\033[3A")

        sleep(delay)

except KeyboardInterrupt:
    print(ansi_red + "\n\n---End---\n" + ansi_std + ansi_crs_on)
