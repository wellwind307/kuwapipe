@echo off
rem ===========================================================================
rem run_kw_sim.bat -- compile and run the self-checking testbench of video_kuwahara
rem
rem Usage (run inside this sim\ folder):
rem     run_kw_sim.bat
rem
rem Prereq: the small-vector hex files are shipped with the package. To
rem regenerate them:  python verify_kuwahara.py --tb
rem
rem All paths are derived from this script location, so the whole package
rem can be moved / renamed freely.
rem ===========================================================================
setlocal
set "HERE=%~dp0"
set "RTL=%HERE%..\src\base.srcs\sources_1\new"

rem Prefer the Vivado found on PATH; otherwise fall back to the local install.
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
if not defined VIVADO_BIN echo [run_kw_sim] using Vivado from PATH

rem Resolve a working Python: honour %PYTHON%, else try "python", else "py -3".
rem (On some hosts "python" is only the Microsoft Store stub, which is not usable.)
set "PY=%PYTHON%"
if defined PY goto havepy
python -c "import sys" >nul 2>nul && set "PY=python"
if defined PY goto havepy
py -3 -c "import sys" >nul 2>nul && set "PY=py -3"
:havepy

cd /d "%HERE%"
if not exist "tb_kw_in.hex" (
  echo [run_kw_sim] tb_kw_in.hex not found, generating vectors ...
  %PY% verify_kuwahara.py --tb
  if errorlevel 1 goto fail
)
if not exist work mkdir work
pushd work
copy /y ..\tb_kw_in.hex  . >nul
copy /y ..\tb_kw_exp.hex . >nul

call "%XVLOG%" --nolog "%RTL%\luma_q8.v" "%RTL%\box4col.v" "%RTL%\linebuf.v" "%RTL%\kuwahara.v" "%RTL%\video_kuwahara.v" ..\tb_video_kuwahara.v
if errorlevel 1 goto fail
call "%XELAB%" --nolog tb_video_kuwahara -s kw_snap
if errorlevel 1 goto fail
call "%XSIM%" --nolog kw_snap -runall
if errorlevel 1 goto fail
popd
echo.
echo [run_kw_sim] DONE - see the === PASS === / === FAIL === line above
exit /b 0

:fail
popd
echo [run_kw_sim] ERROR - see log above
exit /b 1
