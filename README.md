# CT5 Final trên FPGA AX309

Bản Verilog chuyển từ mạch CT5 Final trong Logisim. Chương trình và bảng điều khiển đã nhúng trong Verilog; không cần nạp file `.hex` riêng.

## Build và nạp

1. Tạo project mới trong Xilinx ISE 14.7. Chọn Spartan-6 **XC6SLX9**, package **FTG256**, speed grade **-2**.
2. Thêm `ax309_ct5_final.v` và `ax309_ct5_final.ucf`. Chọn top **`ax309_top`**.
3. Chạy **Synthesize → Implement Design → Generate Programming File**.
4. Nạp **`ax309_top.bit`** vừa tạo qua iMPACT/JTAG.

## Điều khiển

| Nút | Chức năng |
|---|---|
| RESET | Reset CPU |
| KEY1 | Thực hiện một lệnh |
| KEY2 | Reset và bắt đầu tự chạy |
| KEY3 | Tạm dừng hoặc tiếp tục |
| KEY4 | Đổi giữa ba trang hiển thị |

Kết quả dự kiến sau khi tự chạy: **PC=2A, R1=01, R2=04, R3=0A, RAM[05]=2A** (hex). Chương trình đến lệnh `J 2A` tại địa chỉ `2A` sau 34 lệnh; bộ điều khiển dừng chế độ tự chạy.
