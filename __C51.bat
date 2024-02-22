@echo off
::This file was created automatically by CrossIDE to compile with C51.
C:
cd "\Users\qiuyu\OneDrive\Documents\GitHub\Elec291_Lab1\"
"C:\CrossIDE\Call51\Bin\c51.exe" --use-stdout  "C:\Users\qiuyu\OneDrive\Documents\GitHub\Elec291_Lab1\hello.c"
if not exist hex2mif.exe goto done
if exist hello.ihx hex2mif hello.ihx
if exist hello.hex hex2mif hello.hex
:done
echo done
echo Crosside_Action Set_Hex_File C:\Users\qiuyu\OneDrive\Documents\GitHub\Elec291_Lab1\hello.hex
