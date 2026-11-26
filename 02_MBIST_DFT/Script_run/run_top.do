
transcript on
if {[file exists work]} { vdel -lib work -all }
vlib work

vlog ../../01_RTL_Design/sram_1rw.v
vlog ../MBIST_rtl/mbist_controller.v
vlog ../MBIST_rtl/sram_mbist_top.v
vlog -sv ../tb_top/tb_top.sv

vsim -voptargs=+acc work.tb_top

add wave -divider "CHE DO"
add wave -noupdate sim:/tb_top/clk
add wave -noupdate sim:/tb_top/test_mode
add wave -noupdate sim:/tb_top/test_start
add wave -noupdate sim:/tb_top/mem_sel
add wave -noupdate -radix ascii sim:/tb_top/dut/u_mbist/state_name

add wave -divider "NORMAL PORT"
add wave -noupdate sim:/tb_top/func_cs
add wave -noupdate sim:/tb_top/func_we
add wave -noupdate -radix hex sim:/tb_top/func_addr
add wave -noupdate -radix hex sim:/tb_top/func_din
add wave -noupdate -radix hex sim:/tb_top/func_dout

add wave -divider "KET QUA"
add wave -noupdate sim:/tb_top/test_done
add wave -noupdate sim:/tb_top/test_fail
add wave -noupdate sim:/tb_top/mem_done_vec
add wave -noupdate sim:/tb_top/mem_fail_vec

run -all
