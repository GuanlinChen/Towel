open T;;
open Stdint;;
open Tasm_ast;;
open Ort;;

type ctx_t = {id: uint64; ret_addr: uint64};;
type module_t = {ort: ort_t; exs: scope};;

type func_call_type = RegularCall | TailRecursiveCall;;
(* In tail recursive calls, push-tail-name jumps two more lines,
   also fun-arg fetches from current data stack rather than parent
   data stack. *)

let current_module = {ort = make_ort; exs = Hashtbl.create 512};;
let modules:(uint64, module_t) Hashtbl.t = Hashtbl.create 512;;

let dss_ = [];;
let scps_ = [];;
let ctxs_ = [];;
let aus_=[];;     //


let tos = List.hd;;
let ntos = List.tl;;
let rec string_of_value r =
  match (lookup_val current_module.ort todss).v with
        OVInt(i) -> Big_int.to_string i
        | OVFixedInt(i) -> Int64.to_string i
        | OVUFixedInt(i) -> Uint64.to_string i
        | OVFloat(f) -> string_of_float f
        | OVString(s) -> s
        | OVList(rs) -> Printf.sprintf "[%s]" (String.concat " " (List.map string_of_value rs))
        | OVTuple(rs) -> Printf.sprintf "[%s]" (String.concat " " (List.map string_of_value rs));;


let exec insts =
  let rec __exec ctxs dss scps ip =
    let push_todss x = x::(tos dss)::(ntos dss)
    let push_aus x=x::aus   (*we also need to build a auxiliary stack*)
    in let todss = tos (tos dss)
    in let pop_todss = (ntop (tos dss))::(ntos dss)
    in let pop_toctxs = (ntop (tos ctxs))::(ntos ctxs)
    in let next_ip = succ ip
    in let inst = insts.(ip)
    in match inst with
      PUSH_INT(ArgLit(VInt(i))) ->
      let nr = new_int current_module.ort i
      in __exec ctxs (push_todss nr) scps next_ip
    | PUSH_FINT(ArgLit(VFixedInt(i))) ->
      let nr = new_fint current_module.ort i
      in __exec ctxs (push_todss nr) scps next_ip
    | PUSH_UFINT(ArgLit(UVFixedInt(i))) ->
      let nr = new_ufint current_module.ort i
      in __exec ctxs (push_todss nr) scps next_ip
    | PUSH_FLOAT(ArgLit(VFloat(i))) ->
      let nr = new_float current_module.ort i
      in __exec ctxs (push_todss nr) scps next_ip
    | PUSH_STRING(ArgLit(VString(i))) ->
      let nr = new_string current_module.ort i
      in __exec ctxs (push_todss nr) scps next_ip  
    | PATPUSH_FUN(Arglit(i))->
       let ()=push_aus (new_function current_module.ort i) 
        in __exec ctxs pop_todss scps next_ip                
    | PATPUSH_INT(Arglit(i))->
       let ()=push_aus (new_int current_module.ort i) 
        in __exec ctxs pop_todss scps next_ip
    | PATPUSH_FINT(Arglit(i))->
       let ()=push_aus (new_fint current_module.ort i) 
        in __exec ctxs pop_todss scps next_ip
    | PATPUSH_UFINT(Arglit(i))->
       let ()=push_aus (new_ufint current_module.ort i) 
        in __exec ctxs pop_todss scps next_ip
    | PATPUSH_FLOAT(Arglit(i))->                       (*There is no new_float*) 
       let ()=push_aus (     new_ current_module.ort i) 
        in __exec ctxs pop_todss scps next_ip
    | MAKE_INT(Arglit(i))->
      let  ()= new_int current_module.ort i 
      in __exec ctxs dss scps next_ip              
    | MAKE_FINT(Arglit(i))->
      let  ()= new_fint current_module.ort i 
      in __exec ctxs dss scps next_ip           
    | MAKE_UFINT(Arglit(i))->
      let  ()= new_ufint current_module.ort i 
      in __exec ctxs dss scps next_ip     //
    | POP_STACK -> __exec ctxs pop_todss scps next_ip
    | PUSH_STACK -> __exec ctxs ([]::dss) scps next_ip
    | POP_SCOPE -> __exec ctxs dss (pop_scope scps) next_ip
    | PUSH_SCOPE -> __exec ctxs dss (push_scope scps) next_ip
    | PUSH_NAME(List.map (fun x -> ArgLit(x)) nonempty_list(VUFixedInt(i))) -> 
    | MAKE_FUN(ArgLit(VUFixedInt(i))) -> 
      let () = new_function current_module.ort i 
      in __exec ctxs dss scps next_ip
    | BIND(ArgLit(VUFixedInt(i))) -> __exec ctxs dss (push_name scps i (nref_of current_module.ort)) next_ip
    | FUN_ARG(ArgLit(VInt(i))) ->
      let () = __exec ctxs dss (push_name scps i (tos (tos pop_todss)) next_ip
    | JUMP(ArgLit(VUFixedInt(p))) -> __exec ctxs dss scps p
    | JNEZ(ArgLit(VUFixedInt(t))) -> 
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i != Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i != 0 then t else next_ip
        | OVUFixedInt(i) -> if i != 0 then t else next_ip
        | OVFloat(f) -> if f != 0 then t else next_ip
      in __exec ctxs dss scps i
    | JEZ(ArgLit(VUFixedInt(t))) -> 
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i = Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i = 0 then t else next_ip
        | OVUFixedInt(i) -> if i = 0 then t else next_ip
        | OVFloat(f) -> if f = 0 then t else next_ip
      in __exec ctxs dss scps i
    | JGZ(ArgLit(VUFixedInt(t))) -> 
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i > Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i > 0 then t else next_ip
        | OVUFixedInt(i) -> if i > 0 then t else next_ip
        | OVFloat(f) -> if f > 0 then t else next_ip
      in __exec ctxs dss scps i
    | JGEZ(ArgLit(VUFixedInt(t))) -> 
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i >= Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i >= 0 then t else next_ip
        | OVUFixedInt(i) -> if i >= 0 then t else next_ip
        | OVFloat(f) -> if f >= 0 then t else next_ip
      in __exec ctxs dss scps i
    | JLZ(ArgLit(VUFixedInt(t))) -> 
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i < Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i < 0 then t else next_ip
        | OVUFixedInt(i) -> if i < 0 then t else next_ip
        | OVFloat(f) -> if f < 0 then t else next_ip
      in __exec ctxs dss scps i
    | JLEZ(ArgLit(VUFixedInt(t))) -> 
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i <= Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i <= 0 then t else next_ip
        | OVUFixedInt(i) -> if i <= 0 then t else next_ip
        | OVFloat(f) -> if f <= 0 then t else next_ip
      in __exec ctxs dss scps i
    | HJNEZ(ArgLit(VUFixedInt(t))) ->
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i != Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i != 0 then t else next_ip
        | OVUFixedInt(i) -> if i != 0 then t else next_ip
        | OVFloat(f) -> if f != 0 then t else next_ip
      in __exec ctxs pop_todss scps 
    | HJEZ(ArgLit(VUFixedInt(t))) ->
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i = Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i = 0 then t else next_ip
        | OVUFixedInt(i) -> if i = 0 then t else next_ip
        | OVFloat(f) -> if f = 0 then t else next_ip
      in __exec ctxs pop_todss scps i
    | HJGZ(ArgLit(VUFixedInt(t))) ->
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i > Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i > 0 then t else next_ip
        | OVUFixedInt(i) -> if i > 0 then t else next_ip
        | OVFloat(f) -> if f > 0 then t else next_ip
      in __exec ctxs pop_todss scps i
    | HJGEZ(ArgLit(VUFixedInt(t))) ->
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i >= Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i >= 0 then t else next_ip
        | OVUFixedInt(i) -> if i >= 0 then t else next_ip
        | OVFloat(f) -> if f >= 0 then t else next_ip
      in __exec ctxs pop_todss scps i
    | HJLZ(ArgLit(VUFixedInt(t))) ->
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i < Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i < 0 then t else next_ip
        | OVUFixedInt(i) -> if i < 0 then t else next_ip
        | OVFloat(f) -> if f < 0 then t else next_ip
      in __exec ctxs pop_todss scps i
    | HJLEZ(ArgLit(VUFixedInt(t))) ->
      let i = match (lookup_val current_module.ort todss).v with
        OVInt(i) -> if i <= Big_int.zero then t else next_ip
        | OVFixedInt(i) -> if i <= 0 then t else next_ip
        | OVUFixedInt(i) -> if i <= 0 then t else next_ip
        | OVFloat(f) -> if f <= 0 then t else next_ip
      in __exec ctxs pop_todss scps i
    | RET -> 
      let i＝ (tos ctxs)
      in let (tos (tos pop_todss)) = todss
      in __exec pop_toctxs  pop_todss (pop_scope scps) (succ i)



    | SHOW -> 
      let () = (print_string (string_of_value todss))
     in __exec ctxs pop_todss scps next_ip
      (* !!! *)
  in __exec ctxs_ dss_ scps_ 0
