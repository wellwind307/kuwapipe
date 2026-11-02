@echo off
rem ===========================================================================
rem run_kw_sim.bat - compile + run the self-checking testbench of video_kuwahara
rem Usage: run this file inside the vs_sim folder.
rem Prereq: python ..\verify_kuwahara.py --tb   (writes tb_kw_in.hex / tb_kw_exp.hex)
rem ===========================================================================
setlocal
set VIV=C:\Users\30750\Myvivado\2025.2\Vivado\bin
set SRC=%~dp0..\base.srcs\sources_1\new
if not exist work mkdir work
pushd work
if not exist tb_kw_in.hex  copy ..\tb_kw_in.hex  . >nul
if not exist tb_kw_exp.hex copy ..\tb_kw_exp.hex . >nul
call "%VIV%\xvlog.bat" --nolog "%SRC%\luma_q8.v" "%SRC%\box4col.v" "%SRC%\linebuf.v" "%SRC%\kuwahara.v" "%SRC%\video_kuwahara.v" ..\tb_video_kuwahara.v
if errorlevel 1 goto fail
call "%VIV%\xelab.bat" --nolog tb_video_kuwahara -s kw_snap
if errorlevel 1 goto fail
call "%VIV%\xsim.bat" --nolog kw_snap -runall
if errorlevel 1 goto fail
popd
echo.
echo [run_kw_sim] DONE - see the === PASS === / === FAIL === line above
exit /b 0
:fail
popd
echo [run_kw_sim] ERROR - see log above
exit /b 1
