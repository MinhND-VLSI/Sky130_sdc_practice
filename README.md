# Sky130 SDC Practice — Sequential Adder Timing Closure

Bài thực hành viết SDC constraint cho một module sequential (có flip-flop, async reset,
feedback path nội bộ), chạy qua flow Yosys (synthesis) + OpenSTA (static timing analysis)
trên thư viện chuẩn Sky130 HD.

## Mục tiêu

- Hiểu rõ từng loại timing path: Input→Register, Register→Register, Register→Output
- Viết đúng các constraint cơ bản: `create_clock`, `set_input/output_delay`,
  `set_clock_uncertainty`, `set_false_path`, `set_max_fanout`, `set_max_transition`
- Đọc và phân tích report STA thật (cả trường hợp PASS lẫn FAIL)
- Hiểu WNS (Worst Negative Slack) và TNS (Total Negative Slack)

## Thiết kế: `seq_adder.v`

Bộ cộng dồn tuần tự 8-bit: mỗi chu kỳ clock, nếu `en=1`, `data_out` được cộng dồn với
`data_in` (`data_out <= data_out + data_in`). Có async active-low reset (`rst_n`).

Module này minh họa đủ 4 loại path cần quan tâm khi viết SDC:

| Loại path | Ví dụ trong module | Constraint tương ứng |
|---|---|---|
| Input port → Register | `data_in`, `en` → FF | `set_input_delay` |
| Register → Register (feedback) | `data_out` → logic cộng → `data_out` | tự động check qua `create_clock` |
| Register → Output port | FF → `data_out`, `valid_out` | `set_output_delay` |
| Async reset | `rst_n` | `set_false_path` |

## Flow chạy thử

```bash
# 1. Tổng hợp RTL -> gate-level netlist bằng Yosys
yosys -p "read_verilog seq_adder.v; synth -top seq_adder; \
          dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          write_verilog seq_adder_netlist.v"

# 2. Chạy OpenSTA (qua Docker image chính thức của OpenROAD)
docker run -it -v $(pwd):/input openroad/opensta
# trong TCL shell của OpenSTA:
source /input/run_sta.tcl
```

File `.lib` của Sky130 HD không được đính kèm trong repo này (thuộc PDK, không nên commit) —
lấy qua [Volare](https://github.com/efabless/volare) hoặc cài đặt cùng OpenLane.

## Kết quả thí nghiệm 1 — `seq_adder_10ns.sdc` (period = 10ns, 100MHz)

Constraint chuẩn, period dư cho logic combinational bên trong (10 gate,
tổng delay ~4.53ns).

| Check | Data required | Data arrival | Slack | Kết quả |
|---|---|---|---|---|
| Setup (max) | 9.75 ns | 4.53 ns | **+5.22 ns** | MET |
| Hold (min) | 0.12 ns | 0.41 ns | **+0.29 ns** | MET |

Chi tiết: [`results/pass_10ns.txt`](results/pass_10ns.txt)

## Kết quả thí nghiệm 2 — `seq_adder_2ns.sdc` (period = 2ns, 500MHz)

Hạ period xuống thấp để quan sát setup violation — logic combinational (4.53ns)
không thể nào vừa trong 1 chu kỳ 2ns.

| Check | Data required | Data arrival | Slack | Kết quả |
|---|---|---|---|---|
| Setup (max) | 1.75 ns | 4.53 ns | **-2.78 ns** | **VIOLATED** |
| Hold (min) | 0.12 ns | 0.41 ns | +0.29 ns | MET (không đổi) |

```
tns max -32.08
wns max -2.78
```

Chi tiết: [`results/fail_2ns.txt`](results/fail_2ns.txt)

### Nhận xét

- **WNS = -2.78** trùng khớp với slack của path xem ở trên — đây chính là path tệ nhất
  trong toàn thiết kế.
- **TNS = -32.08** lớn hơn nhiều so với 1 path đơn lẻ → có nhiều endpoint khác (các bit
  khác của `data_out[7:0]`) cũng đang vi phạm setup cùng lúc, cộng dồn lại.
- **Hold không bị ảnh hưởng** bởi việc đổi period, vì hold check chỉ so sánh trong cùng
  1 chu kỳ clock (giữa cạnh hiện tại và dữ liệu đến ngay sau đó), không liên quan đến
  độ dài chu kỳ kế tiếp.
- Bài học: logic combinational giữa 2 flip-flop (ở đây là phép cộng 8-bit, ~10 gate)
  quyết định tần số tối đa khả thi của thiết kế — muốn chạy nhanh hơn, cần rút ngắn
  chuỗi logic (VD: dùng carry-lookahead thay vì ripple-carry) hoặc thêm pipeline stage.

## Cấu trúc repo

```
seq_adder.v               RTL gốc (sequential, có FF thật)
seq_adder_10ns.sdc         SDC constraint, period=10ns (PASS)
seq_adder_2ns.sdc          SDC constraint, period=2ns  (cố tình VIOLATED để học)
run_sta.tcl                script chạy OpenSTA
results/
  pass_10ns.txt            report đầy đủ, trường hợp PASS
  fail_2ns.txt             report đầy đủ, trường hợp VIOLATED
```
