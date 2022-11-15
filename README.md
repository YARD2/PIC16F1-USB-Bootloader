USB Bootloader for PIC16F1454/5/9
=================================

[Video](https://www.youtube.com/watch?v=QfhlUpleDKA)

This is a minimal, open-source (512-word) USB bootloader for Microchip [PIC16F1454/5/9](http://www.microchip.com/PIC16F1454) microcontrollers. This is a family of low-cost 8-bit devices with a built-in USB serial interface engine.

A PIC programmed with this bootloader presents itself as a [CDC-ACM](http://en.wikipedia.org/wiki/USB_communications_device_class) device ("virtual COM port") allowing it to be used without drivers on certain operating systems. (Mac OS X 10.9+ confirmed)

The bootloader is written entirely in assembly language and uses no Microchip code. It can be assembled with [gputils](http://gputils.sourceforge.net/), which is available via [Homebrew](http://brew.sh) and many other package managers. A [PICkit 3](http://www.microchip.com/PICkit3) is required to initially flash the bootloader onto the device, but afterwards, application code can be loaded using only a standard USB cable and the provided [Python script](usb16f1prog).

A sample C program and Makefile are included to demonstrate how to write application code that coexists with the bootloader. The code has been tested to work with [SDCC](http://sdcc.sourceforge.net).

## What's a bootloader?

Typically, in order to upload firmware to a microcontroller, you need an "in-system programmer" device, like the [PICkit 3](http://www.microchip.com/PICkit3), [AVRISP mkII](http://www.atmel.com/tools/avrispmkii.aspx), or [USBtinyISP](http://www.ladyada.net/make/usbtinyisp/). Every upload operation completely erases the device's flash memory and uploads the new firmware.

This has some downsides: in-system programmers cost money, sometimes they require non-free software without universal OS support, and they can be slow.

A *bootloader* solves these problems. It's a small piece of code that lives in a (typically write-protected) region of the microcontroller's flash memory, and allows firmware to be uploaded via a standardized connection--like USB or [RS-232](http://en.wikipedia.org/wiki/RS-232)--without a special programming device. The popular [Arduino](http://arduino.cc) platform uses a [bootloader](http://arduino.cc/en/Hacking/Bootloader?from=Tutorial.Bootloader) to simplify programming, among other things.

Once an in-system programmer has been used to program the bootloader onto a microcontroller, new application firmware can be uploaded without it. (Almost every modern microcontroller architecture, including the PIC, allows its flash memory to be "self-programmed" by code running on the device itself.) The area of flash memory containing the bootloader is typically marked as protected so that it's not overwritten when uploading new application firmware.

## Read this first!

- This is **experimental** and has barely been tested. A PIC programmed with this bootloader has been confirmed to enumerate and behave correctly under Mac OS X 10.9.5 on a MacBook Pro.
- On Windows rarely the enumeration failed. Just remove and attach it again.
- I don't have a USB protocol analyzer or non-Apple computers to use for testing. You're more than welcome to test the device under Linux or Windows, but I can't provide support for those particular operating systems. Please submit pull requests, send dmesg logs, packet dumps, etc!
- The bootloader implements the absolute minimal amount of the USB and CDC specs required to enumerate and shuffle data back and forth. It is possible that I'm doing things that aren't standards-compliant. Heck, for all I know, your OS might crash when the PIC is connected! You've been warned.

## Features

- Uses the internal oscillator; no crystal or any external components are required.
- Written in very tight assembly language and uses less than 512 words of program memory.
- The bootloader can be used with a bus-powered or self-powered device. An application can specify whether the hardware is bus-powered or self-powered, and its maximum current draw.
- When power is applied or the device is reset, the chip enters bootloader mode if: 
  a) it does not detect application code, or 
  b) if pin RA3  is held low. 
  In bootloader mode, the device attaches to the USB bus, enumerates, and waits in an idle loop for commands.
- Bootloader code and application code are mutually exclusive. The application does not run in bootloader mode, and the device does not attach to the USB bus when running application code. (unless done so by the application firmware)
- Application code is free to use interrupts; the hardware interrupt vector is in bootloader code space, but all interrupts are forwarded to the application when not in bootloader mode.
- Uploading application code is done with a Python script that uses the [pyserial](http://pyserial.sourceforge.net) and [intelhex](https://pypi.python.org/pypi/IntelHex) packages.
  or win32 samples application in C and Delphi
- Multiple bootloaded PICs can be attached to the USB bus, as long as each one is programmed with a different serial number. The serial number can be specified when assembling the bootloader.
- Bootloader Version support
- Bootlaoder LED blinking support on PIN RC3
- Drop USB and wait before reset (is a bit more secure)
- The bootloader does support hot-plugging
    To reprogram the firmware on a self-powered device, the
    User Application have to disable Timer1 (if you use LED support), disable all interrupts drop the USB, wait, and goto 0x001C.
	
    XC8 2.x example:
```      
	T1CON  = 0;
	T1GCON = 0;
	INTCONbits.PEIE = 0;
	INTCONbits.GIE  = 0;
	UCONbits.USBEN  = 0; // detach from USB BUS
	for(k=0;k<125;k++) __delay_ms(10); //recommended (!) to wait min. 1 second 
	#asm
	  movlp 0x00
	  goto 0x001C
	#endasm
```

- Support for MPLAB (8.92) using MPSAM 
  MPLABx don't support MPASM any more. You can download MPLAB8 from Microchip Archive page
  [Microchip Archive]https://www.microchip.com/en-us/tools-resources/archives/mplab-ecosystem
- A Makefile is provided for developing application code using the SDCC open-source C compiler.
- Thanks to https://pid.codes to assign a PID
	VENDOR_ID	0x1209
	PRODUCT_ID	0x200A

## Limitations

- A PIC16F145x chip of silicon revision **A5 or later** is required due to an issue with writing to program memory on revision A2 parts. The value at address `0x8006` in configuration space should be `0x1005` or later. See the [silicon errata document](http://ww1.microchip.com/downloads/en/DeviceDoc/80000546F.pdf) for more information.
- The configuration words are hard-coded in the bootloader. The device is configured as follows:
    - Internal oscillator, no clock divider, PLL enabled, 3x PLL multiplier
    - Watchdog timer off but may be enabled by software (`SWDTEN` bit)
    - Fail-Safe Clock Monitor, Internal/External Switchover, and clock output are disabled
    - Power-up timer, stack overflow reset, and brown-out reset are enabled
    - If an application requires a different configuration, the bootloader must be recompiled.
- Applications that wish to use the USB interface cannot (easily) reuse the USB code in the bootloader. I'd like to address this in the future.

## Prebuilt HEX file

If you don't want to assemble the bootloader yourself (and you really should, since it's easy and it doesn't require gigabytes of Microchip software to build), 
[here is a prebuilt HEX file.](bootloader.hex) **Note:** No serial numer used, RA3=Bootloader, RC3=LED

## Developing application code

[The sample code](sample_app/blink.c) describes the requirements for C programs, and a Makefile is provided for SDCC/gputils.

To upload code, use the [usb16f1prog](usb16f1prog) Python script like so:

```
usb16f1prog -p /dev/cu.usbmodem0001 mycode.hex
```

In this case, `/dev/cu.usbmodem0001` is the device representing the PIC. (It will be named differently on Windows or Linux.) The `-p` option is not required if you store this value in the `USB16F1PROG_PORT` environment variable.

The application entry point is address `0x200`. On interrupt, the bootloader jumps to address `0x204`. A configuration function that returns the device's power requirements must be present at address `0x202`. This can be a single `retlw` instruction, or a `goto` that branches to a `retlw` instruction elsewhere. This works with C code too: in the 14-bit PIC architecture, constant bytes are encoded as `retlw` instructions, so you can literally "call" a constant.

The power configuration is hard coded to 100mA:

Hint XC8 Compiler:
Select: "Format HEX File for Download" in XC8 -> Linker -> Runtime option
This generate a HEX file which meet the 32Word requirement

Other sample Flash tools are within the win32 folder:
- C 
- Delphi

## License

The contents of this repository, including the bootloader itself, the programming script, and the sample code, is released under a [3-clause BSD license](LICENSE). If you use the bootloader for a project, commercial or non-commercial, linking to this GitHub page is strongly recommended. (Also, let me know! I'd love to hear about it.)

## Credits

Written by Matt Sarnoff.
Update by [DPRCZ] https://github.com/DPRCZ/PIC16F1-USB-Bootloader

Twitter: [@txsector](http://twitter.com/txsector)

