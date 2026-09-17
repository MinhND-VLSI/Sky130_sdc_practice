# Sky130 SDC Practice — Sequential Adder Timing Closure

Bai thuc hanh viet SDC constraint cho mot module sequential (co flip-flop, async reset,
feedback path noi bo), chay qua flow Yosys (synthesis) + OpenSTA (static timing analysis)
tren thu vien chuan Sky130 HD.

## Muc tieu

- Hieu ro tung loai timing path: Input->Register, Register->Register, Register->Output
- Viet dung cac constraint co ban: `create_clock`, `set_input/output_delay`,
  `set_clock_uncertainty`, `set_false_path`, `set_max_fanout`, `set_max_transition`
- Doc va phan tich report STA that (ca truong hop PASS lan FAIL)
- Hieu WNS (Worst Negative Slack) va TNS (Total Negative Slack)

## Thiet ke: `seq_adder.v`

Bo cong don tuan tu 8-bit: moi chu ky clock, neu `en=1`, `data_out` duoc cong don voi
`data_in` (`data_out <= data_out + data_in`). Co async active-low reset (`rst_n`).

Module nay minh hoa du 4 loai path can quan tam khi viet SDC:

| Loai path | Vi du trong module | Constraint tuong ung |
|---|---|---|
| Input port -> Register | `data_in`, `en` -> FF | `set_input_delay` |
| Register -> Register (feedback) | `data_out` -> logic cong -> `data_out` | tu dong check qua `create_clock` |
| Register -> Output port | FF -> `data_out`, `valid_out` | `set_output_delay` |
| Async reset | `rst_n` | `set_false_path` |

## Flow chay thu

```bash
# 1. Tong hop RTL -> gate-level netlist bang Yosys
yosys -p "read_verilog seq_adder.v; synth -top seq_adder; \
          dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          write_verilog seq_adder_netlist.v"

# 2. Chay OpenSTA (qua Docker image chinh thuc cua OpenROAD)
docker run -it -v $(pwd):/input openroad/opensta
# trong TCL shell cua OpenSTA:
source /input/run_sta.tcl
```

File `.lib` cua Sky130 HD khong duoc dinh kem trong repo nay (thuoc PDK, khong nen commit) —
lay qua [Volare](https://github.com/efabless/volare) hoac cai dat cung OpenLane.

## Ket qua thi nghiem 1 — `seq_adder_10ns.sdc` (period = 10ns, 100MHz)

Constraint chuan, period du rong rai cho logic combinational ben trong (10 gate,
tong delay ~4.53ns).

| Check | Data required | Data arrival | Slack | Ket qua |
|---|---|---|---|---|
| Setup (max) | 9.75 ns | 4.53 ns | **+5.22 ns** | MET |
| Hold (min) | 0.12 ns | 0.41 ns | **+0.29 ns** | MET |

Chi tiet: [`results/pass_10ns.txt`](results/pass_10ns.txt)

## Ket qua thi nghiem 2 — `seq_adder_2ns.sdc` (period = 2ns, 500MHz)

Co tinh ha period xuong thap de quan sat setup violation — logic combinational (4.53ns)
khong the nao "vua" trong 1 chu ky 2ns.

| Check | Data required | Data arrival | Slack | Ket qua |
|---|---|---|---|---|
| Setup (max) | 1.75 ns | 4.53 ns | **-2.78 ns** | **VIOLATED** |
| Hold (min) | 0.12 ns | 0.41 ns | +0.29 ns | MET (khong doi) |

```
tns max -32.08
wns max -2.78
```

Chi tiet: [`results/fail_2ns.txt`](results/fail_2ns.txt)

### Nhan xet

- **WNS = -2.78** trung khop voi slack cua path xem o tren — day chinh la path te nhat
  trong toan thiet ke.
- **TNS = -32.08** lon hon nhieu so voi 1 path don le -> co nhieu endpoint khac (cac bit
  khac cua `data_out[7:0]`) cung dang vi pham setup cung luc, cong don lai.
- **Hold khong bi anh huong** boi viec doi period, vi hold check chi so sanh trong cung
  1 chu ky clock (giua canh hien tai va du lieu den ngay sau do), khong lien quan den
  do dai chu ky ke tiep.
- Bai hoc: logic combinational giua 2 flip-flop (o day la phep cong 8-bit, ~10 gate)
  quyet dinh tan so toi da kha thi cua thiet ke — muon chay nhanh hon, can rut ngan
  chuoi logic (VD: dung carry-lookahead thay vi ripple-carry) hoac them pipeline stage.

## Cau truc repo

```
seq_adder.v            RTL goc (sequential, co FF that)
seq_adder_10ns.sdc           SDC constraint, period=10ns (PASS)
seq_adder_2ns.sdc        SDC constraint, period=2ns  (co tinh VIOLATED de hoc)
run_sta.tcl              script chay OpenSTA
results/
  pass_10ns.txt          report day du, truong hop PASS
  fail_2ns.txt            report day du, truong hop VIOLATED
```
