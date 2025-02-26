#! /usr/bin/env python3
# -*- coding: utf-8 -*-

from txpihat import *

# define escape codes for text output
ansi_red = "\033[31m"
ansi_ul = "\033[4m"
ansi_std = "\033[0m" #\033[21m"


# create HAT object
try:
    hat = TxPiHAT()
except Exception as e: # falls das nicht geklappt hat....
    print(str(e))
    exit()

# print HAT object status

print()
print(ansi_red + ansi_ul + "TxPi initialisation test" + ansi_std)
print()
print("TxPiHAT module version:", ansi_red, hat.versionstring, ansi_std)
print("HAT object:", ansi_red, hat, ansi_std)

print()

