@echo **************************
@echo *** Use MinGW compiler ***
@echo **************************
@set PATH=c:\mingw\bin;d:\mingw\bin;%PATH%
@set CC=gcc
call clean.bat
mingw32-make.exe -f make-mingw
pause