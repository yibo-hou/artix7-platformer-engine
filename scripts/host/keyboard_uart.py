#!/usr/bin/env python3
"""Send A/D/Space state to the FPGA from a small focused window."""

import argparse
import sys
import time
import tkinter as tk

import serial
from serial.tools import list_ports


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send A/D/Space state from a focused window to UART."
    )
    parser.add_argument(
        "port",
        nargs="?",
        help='serial port, for example "/dev/cu.usbserial-110"',
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=115200,
        help="UART baud rate (default: 115200)",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=60.0,
        help="transmission rate in Hz (default: 60)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="list available serial ports and exit",
    )
    parser.add_argument(
        "--neutral",
        action="store_true",
        help="send only released state without opening the control window",
    )
    args = parser.parse_args()

    if not args.list and not args.port:
        parser.error("a serial port is required (or use --list)")
    if args.rate <= 0:
        parser.error("--rate must be greater than zero")
    return args


def show_ports() -> None:
    ports = list(list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return

    for port in ports:
        print(f"{port.device}\t{port.description}")


def print_uart_output(uart: serial.Serial) -> None:
    received = uart.read(uart.in_waiting)
    if received:
        sys.stdout.buffer.write(received)
        sys.stdout.buffer.flush()


def run_neutral(uart: serial.Serial, period: float) -> None:
    next_send = time.monotonic()
    while True:
        uart.write(b"\x00")
        print_uart_output(uart)
        next_send += period
        time.sleep(max(0.0, next_send - time.monotonic()))


def run_control_window(uart: serial.Serial, period: float) -> None:
    root = tk.Tk()
    root.title("FPGA Super Mario controls")
    root.geometry("420x150")
    root.resizable(False, False)

    label = tk.Label(
        root,
        text="Click this window, then hold A / D / Space\n"
             "A: left    D: right    Space: jump",
        font=("Sans", 14),
        padx=20,
        pady=25,
    )
    label.pack(fill="both", expand=True)

    pressed: set[str] = set()
    state = 0
    closed = False

    def update_state() -> None:
        nonlocal state
        state = 0
        if "a" in pressed:
            state |= 0x01
        if "d" in pressed:
            state |= 0x02
        if "space" in pressed:
            state |= 0x04

    def key_press(event: tk.Event) -> None:
        key = event.keysym.lower()
        if key in {"a", "d", "space"}:
            pressed.add(key)
            update_state()

    def key_release(event: tk.Event) -> None:
        key = event.keysym.lower()
        pressed.discard(key)
        update_state()

    def tick() -> None:
        if closed:
            return
        uart.write(bytes((state,)))
        print_uart_output(uart)
        root.after(max(1, round(period * 1000.0)), tick)

    def close() -> None:
        nonlocal closed
        closed = True
        uart.write(b"\x00")
        uart.flush()
        root.destroy()

    root.bind("<KeyPress>", key_press)
    root.bind("<KeyRelease>", key_release)
    root.protocol("WM_DELETE_WINDOW", close)
    root.after(0, tick)
    root.focus_force()
    root.mainloop()


def main() -> None:
    args = parse_args()
    if args.list:
        show_ports()
        return

    period = 1.0 / args.rate

    with serial.Serial(args.port, args.baud, timeout=0) as uart:
        print(
            f"Sending to {args.port} at {args.baud} baud and {args.rate:g} Hz."
        )
        print("Controls: A=0x01, D=0x02, Space=0x04.")

        try:
            if args.neutral:
                run_neutral(uart, period)
            else:
                run_control_window(uart, period)
        except KeyboardInterrupt:
            print("\nStopped.")
        finally:
            # Release every control when the program exits.
            uart.write(b"\x00")
            uart.flush()


if __name__ == "__main__":
    main()
