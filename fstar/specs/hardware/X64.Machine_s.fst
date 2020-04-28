module X64.Machine_s
open FStar.Mul
open Defs_s

unfold let pow2_32 = Words_s.pow2_32
unfold let pow2_64 = Words_s.pow2_64
unfold let pow2_128 = Words_s.pow2_128

unfold let nat8 = Words_s.nat8
unfold let nat16 = Words_s.nat16
unfold let nat32 = Words_s.nat32
unfold let nat64 = Words_s.nat64
let int_to_nat64 (i:int) : n:nat64{0 <= i && i < pow2_64 ==> i == n} =
  Words_s.int_to_natN pow2_64 i
unfold let quad32 = Types_s.quad32

type reg =
  | Rax
  | Rbx
  | Rcx
  | Rdx
  | Rsi
  | Rdi
  | Rbp
  | Rsp
  | R8
  | R9
  | R10
  | R11
  | R12
  | R13
  | R14
  | R15

type imm8 = i:int{0 <= i && i < 256}
type xmm = i:int{0 <= i /\ i < 16}

type mem_entry =
| Mem8: v:nat8 -> mem_entry
| Mem16: v:nat16 -> mem_entry
| Mem32: v:nat32 -> mem_entry
| Mem64: v:nat64 -> mem_entry

type memory = Map.t int mem_entry

let regs_t = FStar.FunctionalExtensionality.restricted_t reg (fun _ -> nat64)
let xmms_t = FStar.FunctionalExtensionality.restricted_t xmm (fun _ -> quad32)
[@@va_qattr] unfold let regs_make (f:reg -> nat64) : regs_t = FStar.FunctionalExtensionality.on_dom reg f
[@@va_qattr] unfold let xmms_make (f:xmm -> quad32) : xmms_t = FStar.FunctionalExtensionality.on_dom xmm f

noeq type state = {
  ok: bool;
  regs: regs_t;
  xmms: xmms_t;
  flags: nat64;
  mem: memory;
}

let valid_mem64 (addr:int) (m:memory) : bool =
  match Map.sel m addr with Mem64 v -> true | _ -> false

assume val load_mem64 (addr:int) (m:memory) : Pure nat64
  (requires True)
  (ensures fun n -> match Map.sel m addr with Mem64 v -> v == n | _ -> True)

let store_mem64 (addr:int) (v:nat64) (m:memory) : memory =
  Map.upd m addr (Mem64 v)

type maddr =
  | MConst: n:int -> maddr
  | MReg: r:reg -> offset:int -> maddr
  | MIndex: base:reg -> scale:int -> index:reg -> offset:int -> maddr

[@@va_qattr]
type operand =
  | OConst: n:int -> operand
  | OReg: r:reg -> operand
  | OMem: m:maddr -> operand

type precode (t_ins:Type0) (t_ocmp:Type0) =
  | Ins: ins:t_ins -> precode t_ins t_ocmp
  | Block: block:list (precode t_ins t_ocmp) -> precode t_ins t_ocmp
  | IfElse: ifCond:t_ocmp -> ifTrue:precode t_ins t_ocmp -> ifFalse:precode t_ins t_ocmp -> precode t_ins t_ocmp
  | While: whileCond:t_ocmp -> whileBody:precode t_ins t_ocmp -> precode t_ins t_ocmp

let valid_dst (o:operand) : bool =
  not (OConst? o || (OReg? o && Rsp? (OReg?.r o)))
