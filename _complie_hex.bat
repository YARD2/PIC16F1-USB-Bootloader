set gppath=C:\gputils\bin\gpasm.exe
set gpheader=C:\gputils\header 
set BLpath=C:\PIC16F1-USB-Bootloader
%gppath% -f -p p16f1454 -I %BLpath% -I %gpheader% %BLpath%\bootloader.asm -o %BLpath%\CDCHEX.hex
pause