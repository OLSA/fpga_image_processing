import serial
import time
import numpy as np
import matplotlib.pyplot as plt

PORT = "COM4"
BAUD = 115200
TIMEOUT = 10

FORMAT_MAP = {
    0x00: ("Invert RGB565", 2),
    0x01: ("Threshold 8-bit", 1),
    0x02: ("Grayscale 8-bit", 1),
    0x03: ("Sobel 8-bit", 1),
}

def read_exact(ser, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = ser.read(n - len(buf))
        if not chunk:
            break
        buf += chunk
    return bytes(buf)

def find_sync(ser):
    sync = b"\xAA\x55"
    win = bytearray()
    while True:
        b = ser.read(1)
        if not b:
            return False
        win += b
        if len(win) > 2:
            win = win[-2:]
        if win == sync:
            return True

def main():
    ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)
    try:
        print("Waiting for AA55...")
        if not find_sync(ser):
            print("Timeout waiting for sync.")
            return

        hdr = read_exact(ser, 7)  # size(4) + fmt(1) + w(1) + h(1)
        if len(hdr) != 7:
            print("Incomplete header.")
            return

        size = int.from_bytes(hdr[0:4], "little")
        fmt  = hdr[4]
        w    = hdr[5]
        h    = hdr[6]

        name, bpp = FORMAT_MAP.get(fmt, ("Unknown", 1))
        print(f"Format: {name} (0x{fmt:02X})")
        print(f"Res: {w}x{h}, size={size}, bpp={bpp}")

        expected = w * h * bpp
        if size != expected:
            print(f"Size mismatch: expected {expected}, got {size}")
            return

        payload = read_exact(ser, size)
        if len(payload) != size:
            print(f"Incomplete payload: {len(payload)}/{size}")
            return

        plt.figure()
        plt.title(f"{name} {w}x{h}")
        plt.axis("off")

        if bpp == 1:
            img = np.frombuffer(payload, dtype=np.uint8).reshape((h, w))
            plt.imshow(img, cmap="gray")
        else:
            img16 = np.frombuffer(payload, dtype="<u2").reshape((h, w))
            r = ((img16 >> 11) & 0x1F) << 3
            g = ((img16 >> 5)  & 0x3F) << 2
            b = (img16 & 0x1F) << 3
            rgb = np.dstack((r, g, b))
            plt.imshow(rgb)

        plt.show()

    finally:
        ser.close()

if __name__ == "__main__":
    main()
