# Aleph P Preamp Controller — PIC16F684 Firmware

Assembly firmware for a PIC16F684 microcontroller that drives the front-panel controls and relay switching of a solid-state audio preamplifier. Written in 2005–2006 using Microchip MPASM.

## What it controls

- **Volume** — left and right channels independently, 64 steps via 8-bit relay networks (one per channel)
- **Balance** — trims left or right channel down relative to the other
- **Input selection** — 5 inputs (3 balanced, 2 single-ended), relay-switched
- **Mute** — relay-switched, with a front-panel toggle switch
- **Display** — two 2-digit 7-segment LED displays showing current volume level (00–63)

## Hardware

**Microcontroller:** Microchip PIC16F684, internal 1 MHz oscillator

**Inputs (PORTA):**
| Pins | Function |
|------|----------|
| RA[1:0] | Volume quadrature encoder (gray code) |
| RA[3:2] | Balance quadrature encoder (gray code) |
| RA[5:4] | Input selector quadrature encoder (gray code) |

**Inputs (PORTC):**
| Pin | Function |
|-----|----------|
| RC5 | Mute toggle switch |

**Outputs:** 8 daisy-chained 8-bit shift registers driven serially via PORTC, latched in parallel. From farthest to nearest in the chain:

| SR | Contents |
|----|----------|
| 1–2 | Right channel 7-segment display (low digit, high digit) |
| 3–4 | Left channel 7-segment display (low digit, high digit) |
| 5 | Input select LEDs + mute LED |
| 6 | Input select relays + mute relay |
| 7 | Right volume relays (8-bit) |
| 8 | Left volume relays (8-bit) |

## Key features

**Logarithmic volume curve.** A 64-entry lookup table maps the linear encoder position to an 8-bit relay value with a logarithmic response — more resolution at low levels, less at high levels.

**Anti-pop relay sequencing.** On every volume change, the volume relays are first blanked to zero, then re-enabled one bit at a time from LSB to MSB. This prevents the large voltage step that would otherwise occur when the MSB relay switches, which was the dominant source of audible pops.

**3-sample debounce.** PORTA is polled every 3 ms. A transition is only accepted when three consecutive identical readings differ from the last accepted value, giving approximately 9 ms of debounce without using interrupts.

**Quadrature direction detection.** Each encoder's 2-bit gray code is converted to binary, then the direction is determined by comparing the new binary value against (old binary value + 1) mod 4.

**20-second power-up mute.** On startup the output is held muted for 20 seconds to allow the amplifier's coupling capacitors to charge fully before the outputs are connected. During this time "Pu" (power-up) is shown on the displays.

**EEPROM persistence.** Left volume, right volume, and selected input are stored in data EEPROM so the amplifier restores its last state on power-up.

**Board wiring fixups in software.** Due to layout errors on the physical PCB, the mute LED logic is inverted and the select LED bit positions are shifted relative to the relay bit positions. These are corrected in the `load_select_leds` subroutine rather than by reworking the board.

## Shift register protocol — pin wiggling for Pico implementation

This is the most critical section to preserve for any replacement design, since the relay hardware stays as-is.

### PORTC output pins

| Pin | Function |
|-----|----------|
| RC0 | Serial data (DS) |
| RC1 | Shift clock (SRCLK) — rising edge clocks one bit into the chain |
| RC2 | Latch clock (RCLK) — rising edge transfers all shift registers to outputs simultaneously |
| RC3 | Held permanently HIGH throughout operation |

RC[7:4] are inputs. RC3 is always 1 — its exact board function is unknown without the schematic but it must be kept high.

### Clocking one bit

For each bit, MSB first:

```
RC0 = data bit, RC1 = 0   → set data, clock low
RC0 = data bit, RC1 = 1   → rising clock edge, bit clocked in
(repeat for next bit)
```

Data is shifted MSB first. The `rlf` (rotate left) instruction in `serial_shift_8` pushes the MSB into the carry flag, which becomes RC0.

### Latching all outputs at once

After all 64 bits have been shifted in, pulse RC2 high then low to transfer the shift register contents to the output latches — this is what actually moves the relays:

```
RC3=1, RC2=0   (idle)
RC3=1, RC2=1   (rising edge — latch fires, relays update)
RC3=1, RC2=0   (return to idle)
```

All 8 shift registers update simultaneously on this single latch pulse.

### Byte order — what to shift and in what order

Shift 8 bytes, the **farthest shift register first**. The first byte shifted gets pushed to the end of the chain as subsequent bytes are loaded.


| Shift order | Byte | Final SR position |
|-------------|------|-------------------|
| 1st (shifted first) | Right display — low digit | SR 8 (farthest) |
| 2nd | Right display — high digit | SR 7 |
| 3rd | Left display — low digit | SR 6 |
| 4th | Left display — high digit | SR 5 |
| 5th | Input select LEDs + mute LED | SR 4 |
| 6th | Input select relays + mute relay | SR 3 |
| 7th | Right volume relays | SR 2 |
| 8th (shifted last) | Left volume relays | SR 1 (closest) |

### Bit definitions — relay bytes

**Input select + mute relay byte (SR 3):**

| Bit | Function | Active state |
|-----|----------|-------------|
| 7 | Mute relay | 1 = relay energised = mute OFF (normal operation) |
| 6 | Input 5 relay (single-ended) | 1 = selected |
| 5 | Input 4 relay (single-ended) | 1 = selected |
| 4 | Input 3 relay (balanced) | 1 = selected |
| 3 | Input 2 relay (balanced) | 1 = selected |
| 2 | Input 1 relay (balanced) | 1 = selected |
| 1 | Unused | — |
| 0 | Unused | — |

Only one input bit should be set at a time. Mute is normally 1 (relay held energised during operation); dropping it to 0 opens the relay and mutes the output.

**Volume relay bytes (SR 1 and SR 2):**

Bits [7:0] drive the R-2R resistor relay network directly, where bit 7 is the MSB (highest weight). Values come from the 64-entry logarithmic lookup table — input is a position 0–63, output is a byte 0x00–0xFF. See `volume_table` in the source for the full mapping.

### Anti-pop volume update sequence

Never write a new volume value directly to the relay byte in one step. Instead:

1. Write `0x00` to both volume relay bytes and latch — all volume relays off
2. Write `0x01` (bit 0 only) and latch
3. Write `0x03` (bits 1:0) and latch
4. Write `0x07` (bits 2:0) and latch
5. Continue masking with `0x0F`, `0x1F`, `0x3F`, `0x7F`, `0xFF` — latch after each
6. Final latch has the full target value active

Each latch in steps 2–9 must include the full 8-byte shift for all shift registers (the select and display bytes do not change during a volume update, just resend them unchanged each time).

## Known hardware issue

The input selector encoder shows intermittent behaviour consistent with worn or oxidised contacts. The firmware has no software bug that causes this — the debounce and direction-detection logic are correct. Scoping the two encoder pins while rotating is the recommended first diagnostic step. Contact cleaner applied to the encoder shaft may restore normal operation.

## Possible future work

The physical encoder situation (encoders are epoxied to the faceplate) and the desirability of a richer display (4×20 LCD, WiFi remote control) make a migration to an RP2040/RP2350 (Raspberry Pi Pico / Pico 2) attractive. The relay hardware, anti-pop sequencing approach, logarithmic volume table, and startup mute timing documented here all carry forward directly to any replacement design. The Pico PIO peripheral can decode all three quadrature encoders in hardware with no debounce code required. Since the relays are loaded last in the 64 bit shift register, and those are likely the only ones that survive a controller redesign, only those 3 bytes need to be shifted before the parallel load signal RCLK is taken high.

## File

| File | Description |
|------|-------------|
| `f684temp.asm` | Complete firmware source, Microchip MPASM format |
