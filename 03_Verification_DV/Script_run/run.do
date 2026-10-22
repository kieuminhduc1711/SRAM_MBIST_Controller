transcript on
vlib work
vlog sram_model_stub.v
vlog -sv tb_sram.sv
vsim -voptargs=+acc work.tb_sram

# Chỉ thêm các tín hiệu giao tiếp quan trọng của SRAM
add wave -noupdate sim:/tb_sram/clk
add wave -noupdate sim:/tb_sram/cs
add wave -noupdate sim:/tb_sram/we
add wave -noupdate -radix hex sim:/tb_sram/addr
add wave -noupdate -radix hex sim:/tb_sram/din
add wave -noupdate -radix hex sim:/tb_sram/dout

run -all
transcript file sim.log
write transcript
