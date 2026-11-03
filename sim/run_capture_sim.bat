@echo off
rem ===========================================================================
rem run_capture_sim.bat -- cycle-accurate equivalence co-simulation of the
rem                        capture module (vendor cmos_capture_data vs our
rem                        own ov5640_capture)
rem
rem Usage (run inside this sim\ folder):
rem     run_capture_sim.bat
rem
rem _ref\cmos_capture_data_ref.v is a simulation-only copy of the vendor IP
rem (UTF-8 + `timescale added). It is generated on the fly from the local
rem board resource disk by prepare_capture_ref.py and is NOT redistributed
rem (the vendor code has no open-source licence).
rem
rem Note: do NOT pass -debug to xelab, xsim crashes in that mode on this host.
rem ===========================================================================
setlocal
set "HERE=%~dp0"
set "RTL=%HERE%..\src\base.srcs\sources_1\new"
set "REF=%HERE%_ref\cmos_capture_data_ref.v"

set "VIVADO_BIN=C:\Users\30750\Myvivado\2025.2\Vivado\bin"
where xvlog >nul 2>nul && set "VIVADO_BIN="
if defined VIVADO_BIN (
  set "XVLOG=%VIVADO_BIN%\xvlog.bat"
  set "XELAB=%VIVADO_BIN%\xelab.bat"
  set "XSIM=%VIVADO_BIN%\xsim.bat"
) else (
  set "XVLOG=xvlog.bat"
  set "XELAB=xelab.bat"
  set "XSIM=xsim.bat"
)
if not defined VIVADO_BIN echo [run_capture_sim] using Vivado from PATH

rem Resolve a working Python: honour %PYTHON%, else try "python", else "py -3".
rem (On some hosts "python" is only the Microsoft Store stub, which is not usable.)
set "PY=%PYTHON%"
if defined PY goto havepy
python -c "import sys" >nul 2>nul && set "PY=python"
if defined PY goto havepy
py -3 -c "import sys" >nul 2>nul && set "PY=py -3"
:havepy
if not defined PY echo [run_capture_sim] WARNING: no working Python found; set PYTHON=<python.exe> or pre-generate _ref\cmos_capture_data_ref.v.

cd /d "%HERE%"
if not exist "%REF%" (
  echo [ref] generating simulation reference copy from the vendor package ...
  %PY% prepare_capture_ref.py
  if errorlevel 1 goto fail
)
if not exist _sim_ov5640 mkdir _sim_ov5640
pushd _sim_ov5640

call "%XVLOG%" ..\_ref\cmos_capture_data_ref.v "%RTL%\ov5640_capture.v" ..\tb_ov5640_capture.v
if errorlevel 1 goto fail
call "%XELAB%" tb_ov5640_capture -s sim_capture
if errorlevel 1 goto fail
call "%XSIM%" sim_capture -R
if errorlevel 1 goto fail
popd
echo.
echo [run_capture_sim] DONE - see PASS/FAIL line above
exit /b 0

:fail
popd
echo.
echo SIM FAILED
exit /b 1
