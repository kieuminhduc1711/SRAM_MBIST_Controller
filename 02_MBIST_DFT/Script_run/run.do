transcript on
vlib work

# 1. Biên dịch: Lấy mô hình SRAM của bạn DV, MBIST của bạn, và Testbench
vlog ../../03_Verification_DV/Sram_model/Sram_model_stub.v
vlog ../MBIST_rtl/mbist_controller.v
vlog -sv ../tb_mbist/tb_mbist.sv

# 2. Khởi tạo mô phỏng
vsim -voptargs=+acc work.tb_mbist

# 3. Thêm các nhóm tín hiệu quan trọng vào Waveform
add wave -divider "HE THONG DIEU KHIEN"
add wave -noupdate sim:/tb_mbist/clk
add wave -noupdate sim:/tb_mbist/rst_n
add wave -noupdate sim:/tb_mbist/test_start
add wave -noupdate -radix ascii sim:/tb_mbist/u_mbist/state_name

add wave -divider "GIAO TIEP SRAM (1RW 256x8)"
add wave -noupdate sim:/tb_mbist/mbist_cs
add wave -noupdate sim:/tb_mbist/mbist_we
add wave -noupdate -radix hex sim:/tb_mbist/mbist_addr
add wave -noupdate -radix hex sim:/tb_mbist/mbist_din
add wave -noupdate -radix hex sim:/tb_mbist/sram_dout

add wave -divider "KET QUA KIEM TRA (MBIST)"
add wave -noupdate sim:/tb_mbist/test_done
add wave -noupdate sim:/tb_mbist/test_fail

# 4. Chạy toàn bộ quá trình test
run -all
wave zoom full
