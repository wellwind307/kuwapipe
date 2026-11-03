@echo off
rem ===========================================================================
rem run_style_sim.bat -- self-check of the dither / posterize stage (video_style)
rem
rem Usage (run inside this sim\ folder):
rem     run_style_sim.bat
rem
rem The TB feeds one 8x8 constant grey block (V=100, gamma(100)=167) and checks
rem   1) all 64 outputs land on a quantization level (POSTER_LEVELS=16 -> x16)
rem   2) the 8x8 block mean equals gamma(100), i.e. the dither is unbiased
rem Expected output: captured=64  avg_R=167  level_errors=0  +  === PASS ===
rem ===========================================================================
setlocal
set "HERE=%~dp0"
set "RTL=%HERE%..\src\base.srcs\sources_1\new"

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
if not defined VIVADO_BIN echo [run_style_sim] using Vivado from PATH

cd /d "%HERE%"
if not exist work mkdir work
pushd work
rem the TB does $readmemh("gamma_lut.mem"), so the LUT must sit in the run dir
copy /y "%RTL%\gamma_lut.mem" . >nul

call "%XVLOG%" --nolog "%RTL%\video_style.v" ..\tb_video_style.v
if errorlevel 1 goto fail
call "%XELAB%" --nolog tb_video_style -s style_snap
if errorlevel 1 goto fail
call "%XSIM%" --nolog style_snap -runall
if errorlevel 1 goto fail
popd
echo.
echo [run_style_sim] DONE - see the === PASS === / === FAIL === line above
exit /b 0

:fail
popd
echo [run_style_sim] ERROR - see log above
exit /b 1
