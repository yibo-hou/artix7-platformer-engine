#!/usr/bin/env python3
"""Capture a serial port for a bounded duration."""

import argparse
import sys
import time

import serial


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("port")
    parser.add_argument("--seconds", type=float, default=30.0)
    parser.add_argument("--baud", type=int, default=115200)
    args = parser.parse_args()

    deadline = time.monotonic() + args.seconds
    with serial.Serial(args.port, args.baud, timeout=0.2) as uart:
        while time.monotonic() < deadline:
            data = uart.read(4096)
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()


if __name__ == "__main__":
    main()
