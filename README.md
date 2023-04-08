# Nibbler calc

## Simple calculator for [Nibbler 4 Bit computer](https://www.bigmessowires.com/nibbler/)

This program performs 3 basic arithmetic operations on 4-digit integer numbers

Coded entirely in assembly with custom assembly preprocessor (for rudimentary `call`-like instructions, etc.)

Made as part of a bachelor thesis

## Build

To build this project, you'll need:
* Assembler from the [Nibbler file archive](https://www.bigmessowires.com/nibbler.zip)
* Python interpreter

```bash
python preprocessor.py calc.asm

nibbler-assembler -o calcu.bin calcu.asm
```

## Run

Download (and optionally build) Nibbler Simulator from the [Nibbler file archive](https://www.bigmessowires.com/nibbler.zip) mentioned above

![Simulator window](https://user-images.githubusercontent.com/2512758/230735691-392cdaeb-1845-48ca-8365-add314dbbbc8.png)

Open calcu.bin compiled at the previous step and press "Run"

Arrow buttons below "Source view" control cursor (cursor is not visible in Simulator but hopefully will be on the real device)

Press left/right to move cursor

Press up/down to change digits or arithmetic operation (cycles through multiplication, subtraction and addition)

When cursor is on the last digit, press right to get the result

