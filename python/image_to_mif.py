"""
image_to_mif.py

Python skripta za konverziju ulazne slike u MIF format
koji se koristi za dalju obradu u FPGA projektu.
"""
from PIL import Image
import numpy as np

# -------- PARAMETRI --------
W = 200
H = 200
IMAGE_FILE = "lena.jpg"
MIF_FILE = "image_200x200_rgb565.mif"

# -------- UČITAJ I PRIPREMI SLIKU --------
img = Image.open(IMAGE_FILE).convert("RGB")
img = img.resize((W, H))
img_np = np.array(img, dtype=np.uint8)

# RGB888 -> RGB565
r = (img_np[:, :, 0] >> 3).astype(np.uint16)
g = (img_np[:, :, 1] >> 2).astype(np.uint16)
b = (img_np[:, :, 2] >> 3).astype(np.uint16)
rgb565 = (r << 11) | (g << 5) | b

rgb565 = rgb565.flatten()

# Split u bajtove (little endian)
data = []
for px in rgb565:
    data.append(px & 0xFF)        # LOW
    data.append((px >> 8) & 0xFF) # HIGH

# -------- PIŠI MIF --------
with open(MIF_FILE, "w") as f:
    f.write(f"WIDTH=8;\n")
    f.write(f"DEPTH={len(data)};\n\n")
    f.write("ADDRESS_RADIX=DEC;\n")
    f.write("DATA_RADIX=HEX;\n\n")
    f.write("CONTENT BEGIN\n")

    for addr, val in enumerate(data):
        f.write(f"    {addr} : {val:02X};\n")

    f.write("END;\n")

print("MIF file generated:", MIF_FILE)
print("Bytes:", len(data))


