transcript on
vlib work
vlog sram_model_stub.v
vlog -sv tb_sram.sv
vsim -voptargs=+acc work.tb_sram
add wave -r sim:/tb_sram/*
run -all
transcript file sim.log
write transcript
