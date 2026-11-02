transcript on
transcript file sim.log

if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog ../Sram_model/sram_1rw.v
vlog -sv ../testbench/tb_sram.sv

# Đổi work.tb_sram thành work.tb_sram_1rw
vsim -voptargs=+acc work.tb_sram_1rw

# Cập nhật tên module cho các đường sóng dạng sóng
add wave -noupdate sim:/tb_sram_1rw/clk
add wave -noupdate sim:/tb_sram_1rw/cs
add wave -noupdate sim:/tb_sram_1rw/we
add wave -noupdate -radix hex sim:/tb_sram_1rw/addr
add wave -noupdate -radix hex sim:/tb_sram_1rw/din
add wave -noupdate -radix hex sim:/tb_sram_1rw/dout
add wave -noupdate -radix dec sim:/tb_sram_1rw/errors

run -all
transcript file ""
