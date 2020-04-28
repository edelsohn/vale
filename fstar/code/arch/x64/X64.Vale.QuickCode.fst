module X64.Vale.QuickCode
open FStar.Mul
open Defs_s
open X64.Machine_s
open X64.Vale.State
open X64.Vale.Decls

irreducible let qmodattr = ()

type mod_t =
| Mod_None : mod_t
| Mod_ok: mod_t
| Mod_reg: reg -> mod_t
| Mod_xmm: xmm -> mod_t
| Mod_flags: mod_t
| Mod_mem: mod_t
unfold let mods_t = list mod_t
unfold let va_mods_t = mods_t

[@@va_qattr] unfold let va_Mod_None = Mod_None
[@@va_qattr] unfold let va_Mod_ok = Mod_ok
[@@va_qattr] unfold let va_Mod_reg = Mod_reg
[@@va_qattr] unfold let va_Mod_xmm = Mod_xmm
[@@va_qattr] unfold let va_Mod_flags = Mod_flags
[@@va_qattr] unfold let va_Mod_mem = Mod_mem

[@@va_qattr; "opaque_to_smt"]
let mod_eq (x y:mod_t) : Pure bool (requires True) (ensures fun b -> b == (x = y)) =
  match x with
  | Mod_None -> (match y with Mod_None -> true | _ -> false)
  | Mod_ok -> (match y with Mod_ok -> true | _ -> false)
  | Mod_reg rx -> (match y with Mod_reg ry -> rx = ry | _ -> false)
  | Mod_xmm xx -> (match y with Mod_xmm xy -> xx = xy | _ -> false)
  | Mod_flags -> (match y with Mod_flags -> true | _ -> false)
  | Mod_mem -> (match y with Mod_mem -> true | _ -> false)

[@@va_qattr]
let update_state_mod (m:mod_t) (sM sK:state) : state =
  match m with
  | Mod_None -> sK
  | Mod_ok -> va_update_ok sM sK
  | Mod_reg r -> va_update_reg r sM sK
  | Mod_xmm x -> va_update_xmm x sM sK
  | Mod_flags -> va_update_flags sM sK
  | Mod_mem -> va_update_mem sM sK

[@@va_qattr]
let rec update_state_mods (mods:mods_t) (sM sK:state) : state =
  match mods with
  | [] -> sK
  | m::mods -> update_state_mod m sM (update_state_mods mods sM sK)

[@@va_qattr]
unfold let update_state_mods_norm (mods:mods_t) (sM sK:state) : state =
  norm [iota; zeta; delta_attr [`%qmodattr]; delta_only [`%update_state_mods; `%update_state_mod]] (update_state_mods mods sM sK)

let va_lemma_norm_mods (mods:mods_t) (sM sK:state) : Lemma
  (ensures update_state_mods mods sM sK == update_state_mods_norm mods sM sK)
  = ()

[@@va_qattr; qmodattr]
let va_mod_dst_opr64 (o:operand) : mod_t =
  match o with
  | OConst n -> Mod_None
  | OReg r -> Mod_reg r
  | OMem m -> Mod_mem

[@@va_qattr; qmodattr]
let va_mod_reg_opr64 (o:operand) : mod_t =
  match o with
  | OConst n -> Mod_None
  | OReg r -> Mod_reg r
  | OMem m -> Mod_None

[@@va_qattr; qmodattr] let va_mod_xmm (x:xmm) : mod_t = Mod_xmm x

let quickProc_wp (a:Type0) : Type u#1 = (s0:state) -> (wp_continue:state -> a -> Type0) -> Type0

let t_require (s0:state) = state_inv s0
unfold let va_t_require = t_require

let va_t_ensure (#a:Type0) (c:va_code) (mods:mods_t) (s0:state) (k:(state -> a -> Type0)) =
  fun (sM, f0, g) -> eval_code c s0 f0 sM /\ update_state_mods mods sM s0 == sM /\ state_inv sM /\ k sM g

let t_proof (#a:Type0) (c:va_code) (mods:mods_t) (wp:quickProc_wp a) : Type =
  s0:state -> k:(state -> a -> Type0) -> Ghost (state & va_fuel & a)
    (requires t_require s0 /\ wp s0 k)
    (ensures va_t_ensure c mods s0 k)

// Code that returns a ghost value of type a
[@@va_qattr]
noeq type quickCode (a:Type0) : va_code -> Type =
| QProc:
    c:va_code ->
    mods:mods_t ->
    wp:quickProc_wp a ->
    proof:t_proof c mods wp ->
    quickCode a c

[@@va_qattr]
unfold let va_quickCode = quickCode

[@@va_qattr]
unfold let va_QProc = QProc
