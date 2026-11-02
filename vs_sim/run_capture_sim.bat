@echo off
rem ===========================================================================
rem run_capture_sim.bat —— 采集模块等价性协同仿真（原 IP vs 自研 ov5640_capture）
rem
rem 说明：_ref\cmos_capture_data_ref.v 是原 IP 的 UTF-8 仿真副本（补了 timescale），
rem       只用于比对，不参与综合、不进提交包。
rem 注意：xelab 不要加 -debug，本机该模式下 xsim 会崩。
rem ===========================================================================
setlocal
set VIVADO_BIN=C:\Users\30750\Myvivado\2025.2\Vivado\bin
cd /d "%~dp0.."
if not exist _sim_ov5640 mkdir _sim_ov5640
if not exist "_ref\cmos_capture_data_ref.v" (
  echo [ref] generating simulation reference copy from the vendor package...
  python "vs_sim\prepare_capture_ref.py"
  if errorlevel 1 goto :fail
)
cd _sim_ov5640

call "%VIVADO_BIN%\xvlog.bat" "..\_ref\cmos_capture_data_ref.v" "..\base.srcs\sources_1\new\ov5640_capture.v" "..\vs_sim\tb_ov5640_capture.v"
if errorlevel 1 goto :fail
call "%VIVADO_BIN%\xelab.bat" tb_ov5640_capture -s sim_capture
if errorlevel 1 goto :fail
call "%VIVADO_BIN%\xsim.bat" sim_capture -R
if errorlevel 1 goto :fail
goto :eof

:fail
echo.
echo SIM FAILED
exit /b 1
