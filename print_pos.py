#!/usr/bin/env python3
from escpos.printer import Usb
import sys

""" TEROW 58 """
p = Usb(0x416, 0x5011)

p.text(sys.argv[1] + "\n")