transcript on
transcript file sim_fault.log
if {[file exists work]} { vdel -lib work -all }
vlib work

vlog ../Sram_model/sram_fault_model.v
vlog ../../02_MBIST_DFT/MBIST_rtl/mbist_controller.v
vlog -sv ../tb_fault/tb_mbist_fault.sv

vsim -voptargs=+acc work.tb_mbist_fault
add wave -noupdate sim:/tb_mbist_fault/clk
add wave -noupdate sim:/tb_mbist_fault/done_v
add wave -noupdate sim:/tb_mbist_fault/fail_v
run -all
transcript file ""
