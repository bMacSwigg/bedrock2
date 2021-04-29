Require Import bedrock2.NotationsCustomEntry.

Import Syntax Syntax.Coercions BinInt String List.ListNotations.
Local Open Scope string_scope. Local Open Scope Z_scope. Local Open Scope list_scope.

Definition indirect_add : func := let a := "a" in let b := "b" in let c := "c" in
  ("indirect_add", ([a; b; c], [], bedrock_func_body:(
  store(a, load(b) + load(c))
))).

Definition indirect_add_twice : func := let a := "a" in let b := "b" in
  ("indirect_add_twice", ([a;b], [], bedrock_func_body:(
  indirect_add(a, a, b);
  indirect_add(a, a, b)
))).

Require Import bedrock2.WeakestPrecondition.
Require Import coqutil.Word.Interface coqutil.Map.Interface bedrock2.Map.SeparationLogic.
Require Import bedrock2.Semantics bedrock2.FE310CSemantics.

Require bedrock2.WeakestPreconditionProperties.
From coqutil.Tactics Require Import letexists eabstract.
Require Import bedrock2.ProgramLogic bedrock2.Scalars.

Section WithParameters.
  Context {p : FE310CSemantics.parameters}.

  Definition f (a b : word) := word.add (word.add a b) b.

  Local Notation "m =* P" := (P%sep m) (at level 70, only parsing). (* experiment *)
  Instance spec_of_indirect_add : spec_of "indirect_add" :=
    fnspec! "indirect_add" a b c / va Ra vb Rb vc Rc,
    { requires t m := m =* scalar a va * Ra /\ m =* scalar b vb * Rb /\ m =* scalar c vc * Rc;
      ensures t' m' := t=t' /\ m' =* scalar a (word.add vb vc) * Ra }.
  Instance spec_of_indirect_add_twice : spec_of "indirect_add_twice" :=
    fnspec! "indirect_add_twice" a b / va vb R,
    { requires t m := m =* scalar a va * scalar b vb * R;
      ensures t' m' := t=t' /\ m' =* scalar a (f va vb) * scalar b vb * R }.

  Lemma indirect_add_ok : program_logic_goal_for_function! indirect_add.
  Proof. repeat straightline; []; eauto. Qed.

  Lemma indirect_add_twice_ok : program_logic_goal_for_function! indirect_add_twice.
  Proof.
    repeat straightline.
    straightline_call.
    { split; [ecancel_assumption|]. split; ecancel_assumption. }
    repeat straightline.
    straightline_call.
    { split; [ecancel_assumption|]. split; ecancel_assumption. }
    repeat straightline.
    { split; trivial. split; trivial. cbv [f]. ecancel_assumption. }
  Qed.

  Example link_both : spec_of_indirect_add_twice (indirect_add_twice::indirect_add::nil).
  Proof. auto using indirect_add_twice_ok, indirect_add_ok. Qed.

  (* Print Assumptions link_swap_swap_swap_swap. *)
  (* SortedList.* SortedListString.* *)

  (*
  From bedrock2 Require Import ToCString Bytedump.
  Local Open Scope bytedump_scope.
  Goal True.
    let c_code := eval cbv in (byte_list_of_string (c_module (indirect_add_twice::indirect_add::nil))) in
    idtac c_code.
  Abort.
  *)

  Definition indirect_add_three : Syntax.func := let a := "a" in let b := "b" in let c := "c" in
    ("indirect_add_three", ([a;b;c], [], bedrock_func_body:(
    indirect_add(a, a, b);
    indirect_add(a, a, c)
  ))).

  Definition g (a b c : word) := word.add (word.add a b) c.
  Instance spec_of_indirect_add_three : spec_of "indirect_add_three" :=
    fnspec! "indirect_add_three" a b c / va vb vc Rb R,
    { requires t m := m =* scalar a va * scalar c vc * R /\ m =* scalar b vb * Rb;
      ensures t' m' := t=t' /\ m' =* scalar a (g va vb vc) * scalar c vc * R }.

  Lemma indirect_add_three_ok : program_logic_goal_for_function! indirect_add_three.
  Proof.
    repeat straightline.
    straightline_call.
    { split; [ecancel_assumption|]. split; ecancel_assumption. }
    repeat straightline.
    straightline_call.
    { split; [ecancel_assumption|]. split; ecancel_assumption. }
    repeat straightline.
    { split; trivial. split; trivial. cbv [g]. ecancel_assumption. }
  Qed.

  Definition indirect_add_three' : Syntax.func := let a := "a" in let b := "b" in let c := "c" in let out := "out" in let v := "v" in
    ("indirect_add_three'", ([out;a;b;c], [], bedrock_func_body:(
    stackalloc 4 as v {
      indirect_add(v, a, b);
      indirect_add(out, v, c)
    }
  ))).

  Instance spec_of_indirect_add_three' : spec_of "indirect_add_three'" :=
    fnspec! "indirect_add_three'" out a b c / vout va vb vc Ra Rb Rc R,
    { requires t m :=
        m =* scalar out vout * R /\
        m =* scalar a va * Ra /\
        m =* scalar b vb * Rb /\
        m =* scalar c vc * Rc;
      ensures t' m' := t=t' /\ m' =* scalar a (g va vb vc) * R }.

  Lemma indirect_add_three'_ok : program_logic_goal_for_function! indirect_add_three'.
  Proof.
    repeat straightline.
    (* note: we want to introduce only one variable for stack contents 
     * and use it in a all separation-logic facts in the symbolic state *)

    repeat match goal with
           | H : _ |- _ =>
               (* WHY do I need @ in front of the lemma? PARAMRECORDS? *)
               seprewrite_in_by @scalar_of_bytes H
                 ltac:(change width with 32; Lia.lia);
                 let x := fresh "x" in
                 set (word.of_Z _) as x in H; clearbody x; move x at top
           end.
    clear dependent mStack.

    (*
H1 : (scalar a0 x ⋆ (scalar out vout ⋆ R))%sep m2
H2 : (scalar a0 x0 ⋆ (scalar a va ⋆ Ra))%sep m2
H3 : (scalar a0 x1 ⋆ (scalar b vb ⋆ Rb))%sep m2
H4 : (scalar a0 x2 ⋆ (scalar c vc ⋆ Rc))%sep m2
     *)

    straightline_call.
    { split; [exact H1|split]; ecancel_assumption. }

    repeat straightline.
    (*
H15 : (scalar a0 (word.add va vb) ⋆ (scalar out vout ⋆ R))%sep a2
     *)
    (* H15 is an updated version of H1,
       but we really wanted to carry over H2,H3, and H4 as well *)
  Abort.

  (* let's see how this would look like with an alternate spec of [indirect_add] *)

  Remove Hints spec_of_indirect_add : typeclass_instances.
  Instance spec_of_indirect_add_gen : spec_of "indirect_add" :=
    fnspec! "indirect_add" a b c / va Ra vb Rb vc Rc,
    { requires t m := m =* scalar a va * Ra /\ m =* scalar b vb * Rb /\ m =* scalar c vc * Rc;
      ensures t' m' := t=t' /\
        forall va Ra, m =* scalar a va * Ra -> m' =* scalar a (word.add vb vc) * Ra }.

  Lemma indirect_add_gen_ok : program_logic_goal_for_function! indirect_add.
  Proof.
    repeat straightline; []; split; [>|split]; trivial; [].
    (* This goal is unprovable as shown.
       It could be made provable by revealing how the memory was updated
         by modifying the straightline rule for store.
       I don't know how I would do this systematically for non-leaf functions, though. *)
 Abort.

  (* an potential alternative to changing this spec would be to
     - prove  wp.call (post:=p) /\ wp.call(post=q) -> wp.call (post:=p/\q)
     - instantiate the spec of indirect_add multiple times at the call site
       (existentials in postcondition are duplicated for each instantiation)
     but for now, let's prototype with changed spec:
  *)

  Lemma indirect_add_three'_ok : program_logic_goal_for_function! indirect_add_three'.
  Proof.
    repeat straightline.
    (* note: we want to introduce only one variable for stack contents 
     * and use it in a all separation-logic facts in the symbolic state.
     * here we get away with doing it wrong anyway. *)

    repeat match goal with
           | H : _ |- _ =>
               (* WHY do I need @ in front of the lemma? PARAMRECORDS? *)
               seprewrite_in_by @scalar_of_bytes H
                 ltac:(change width with 32; Lia.lia);
                 let x := fresh "x" in
                 set (word.of_Z _) as x in H; clearbody x; move x at top
           end.
    clear dependent mStack.

    straightline_call.
    { split; [exact H1|split]; ecancel_assumption. }
    repeat straightline.
    rename a2 into m.
    (*
H15 : forall (va0 : word) (Ra : mem -> Prop),
      (scalar a0 va0 ⋆ Ra)%sep m2 -> (scalar a0 (word.add va vb) ⋆ Ra)%sep m
     *)
    eapply H15 in H1.
    eapply H15 in H2.
    eapply H15 in H3.
    eapply H15 in H4.
    clear H15.

    straightline_call.
    { split; [>|split]; try ecancel_assumption. }
    repeat straightline.
    rename a3 into m'.
    (*
H15 : forall (va0 : word) (Ra : mem -> Prop),
      (scalar out va0 ⋆ Ra)%sep m ->
      (scalar out (word.add (word.add va vb) vc) ⋆ Ra)%sep m'
     *)
    specialize (H15 _ _ ltac:(ecancel_assumption)).

    (* unrelated: stack deallocation proof, would need scalar-to-bytes lemma *)
  Abort.

End WithParameters.
