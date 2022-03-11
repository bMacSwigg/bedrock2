Require Import Coq.micromega.Lia.
Require Import coqutil.Word.Bitwidth32.
Require Import bedrock2.SepAutoArray bedrock2.SepAuto.
Require Import bedrock2.OperatorOverloading. Local Open Scope oo_scope.
Import Coq.Lists.List.ListNotations. Local Open Scope list_scope.
Require Import bedrock2.ListIndexNotations. Local Open Scope list_index_scope.
Require Import bedrock2.SepBulletPoints. Local Open Scope sep_bullets_scope.

Section WithParameters.
  Context {word: word.word 32} {mem: map.map word Byte.byte}.
  Context {word_ok: word.ok word} {mem_ok: map.ok mem}.

  Add Ring wring : (Properties.word.ring_theory (word := word))
        ((*This preprocessing is too expensive to be always run, especially if
           we do many ring_simplify in a sequence, in which case it's sufficient
           to run it once before the ring_simplify sequence.
           preprocess [autorewrite with rew_word_morphism],*)
         morphism (Properties.word.ring_morph (word := word)),
         constants [Properties.word_cst]).

  Context (cmd: Type).
  Context (wp: cmd -> mem -> (mem -> Prop) -> Prop).
  Context (sample_call: word -> word -> cmd).

  Hypothesis sample_call_correct: forall m a1 n (vs: list word) R (post: mem -> Prop),
      sep (a1 :-> vs : with_len (Z.to_nat (word.unsigned n)) word_array) R m /\
      (forall m',
        (* Currently, the postcondition also needs a `with_len` so that when the caller
           merges the pieces back together, it recognizes the clause as having the
           same shape as in the precondition.
           TODO consider ways of supporting to drop with_len in the postcondition when
           it can be derived like here (List.upd is guaranteed to preserve the length). *)
        sep (a1 :-> List.upd vs 5 (List.nth 5 vs default * (word.of_Z (width := 32) 2))
            : with_len (Z.to_nat (word.unsigned n)) word_array) R m' ->
        post m') ->
      wp (sample_call a1 n) m post.

  Context (sample_post: mem -> Prop).

  (* even this small example needs higher-than-default printing depth to fully display
     the intermediate goals... *)
  Set Printing Depth 100000.

  Definition sample_call_usage_goal := forall ws R addr m,
      (16 <= List.length ws)%nat ->
      sep (addr :-> ws : word_array) R m ->
      wp (sample_call (word.add addr (word.of_Z (2*4)))
                      (word.of_Z 10))
         m (fun m' => sep
           (addr :-> List.upd ws 7 (List.nth 7 ws default * word.of_Z (width := 32) 2)
                         : word_array) R m').

  Lemma use_sample_call_with_tactics_unfolded: sample_call_usage_goal.
  Proof.
    unfold sample_call_usage_goal. intros.
    eapply sample_call_correct.

    (* prove precondition and after intro-ing postcondition, merge back with same lemma
       as used for proving precondition: *)
    put_cont_into_emp_sep.
    use_sep_asm.
    cancel. (* only reifies, because nothing can be canceled without splitting *)
    split_ith_left_to_cancel_with_fst_right 0%nat.
    finish_impl_ecancel.
    intros m' HM'.
    pop_split_sepclause_stack m'.

    (* at the end of the function, prove that computed symbolic state implies desired
       postcondition *)
    use_sep_asm.
    cancel.
    cancel_seps_at_indices_by_implication 0%nat 0%nat. {
      match goal with
      | |- impl1 ?LHS ?RHS => replace LHS with RHS
      end.
      1: exact impl1_refl.
      f_equal.
      clear HM'.
      unfold List.upd, List.upds.
      repeat (repeat word_simpl_step_in_goal; fwd).
      reflexivity.
    }
    exact impl1_refl.
  Qed.

  (* up for discussion: naming, and convention on what position the memory has
     in postcondition, and what to do with calls that don't modify the memory,
     and what to do if the new sep formula is under some existentials
     or under a disjunction -- therefore it's not automated yet in SepCalls.v,
     and here we just pretend that this tactic would always work even though it doesn't *)
  Ltac sep_call_pre_post :=
    after_sep_call; intro_new_mem.

  Lemma use_sample_call_automated: sample_call_usage_goal.
  Proof.
    unfold sample_call_usage_goal. intros.
    eapply sample_call_correct.

    sep_call_pre_post.

    (* at the end of the function, prove that computed symbolic state implies desired
       postcondition, TODO automate as well *)
    use_sep_asm.
    cancel.
    cancel_seps_at_indices_by_implication 0%nat 0%nat. {
      match goal with
      | |- impl1 ?LHS ?RHS => replace LHS with RHS
      end.
      1: exact impl1_refl.
      f_equal.
      unfold List.upd, List.upds.
      repeat (repeat word_simpl_step_in_goal; fwd).
      reflexivity.
    }
    exact impl1_refl.
  Qed.
End WithParameters.
