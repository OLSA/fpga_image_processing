# FPGA Image Processing

Hardverska implementacija obrade digitalnih slika na FPGA platformi, realizovana u okviru projektnog zadatka iz predmeta **Paralelno programiranje** (Elektrotehnički fakultet, Univerzitet u Podgorici).

Projekat demonstrira principe **paralelnog procesiranja** karakteristične za FPGA arhitekture kroz implementaciju više filtera za obradu slike koji rade istovremeno nad istim ulaznim podacima.

---

## Opis projekta

Sistem je realizovan na **CYC5000 FPGA modulu** sa **Intel Cyclone V (5CEBA2U15C8)** čipom.  
Ulazna slika je smještena u internoj FPGA Block RAM memoriji u **RGB565** formatu, a obrada se vrši hardverski, paralelnom instancijacijom više filtera.

Implementirani su sljedeći filteri:
- Invert
- Grayscale
- Threshold (binarizacija)
- Sobel edge detection

Svi filteri su instancirani paralelno i sinhrono primaju iste ulazne piksele. Izbor aktivnog izlaza vrši se pomoću FSM kontrolera i output multipleksera.

Rezultati obrade se prenose na računar putem **UART interfejsa**, gdje se rekonstruišu i prikazuju pomoću Python skripte.

---

## Korišćena platforma i alati

### Hardver
- FPGA modul: **CYC5000 (Trenz Electronic)**
- FPGA čip: **Intel Cyclone V E – 5CEBA2U15C8**
- Interna memorija: ~220 KB Block RAM
- Eksterna memorija: 8 MB SDRAM
- Komunikacija: UART (115200 bps)
- Custom carrier board (DIP switch-evi, tasteri)

### Softver i alati
- **VHDL** – implementacija hardverskih modula
- **Intel Quartus Prime** – sinteza i implementacija
- **Python** – prijem i prikaz slike preko UART-a
- **NumPy / Matplotlib** – obrada i vizualizacija slike

---

## Struktura repozitorijuma

fpga_image_processing/
│
├── vhdl/
│ ├── top_image_processing.vhd
│ ├── filter_invert_rgb565.vhd
│ ├── filter_grayscale.vhd
│ ├── filter_threshold.vhd
│ ├── filter_sobel.vhd
│ ├── image_ram.vhd
│ ├── uart_tx.vhd
│ └── image_processing_pkg.vhd
│
├── python_uart/
│ ├── receive_image_uart.py
│ └── image_to_mif.py
│
└── README.md
