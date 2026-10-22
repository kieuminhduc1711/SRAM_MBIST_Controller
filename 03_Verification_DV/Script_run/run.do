
transcript on
transcript file sim.log

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vlog sram_model_stub.v
vlog -sv tb_sram.sv

vsim -voptargs=+acc work.tb_sram

# Them cac tin hieu giao tiep quan trong cua SRAM
add wave -noupdate sim:/tb_sram/clk
add wave -noupdate sim:/tb_sram/cs
add wave -noupdate sim:/tb_sram/we
add wave -noupdate -radix hex sim:/tb_sram/addr
add wave -noupdate -radix hex sim:/tb_sram/din
add wave -noupdate -radix hex sim:/tb_sram/dout

run -all

transcript file ""
