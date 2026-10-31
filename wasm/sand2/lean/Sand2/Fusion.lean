import Sand2.Thermodynamics

namespace Sand2

/-- Minerals have three declared fusion states. Unsupported vaporization is not
    represented by an unreachable large-number boiling threshold. -/
inductive FusionPhase where
  | solid | melting | liquid
  deriving DecidableEq, BEq, Repr

structure FusionDiagram where
  meltStart : Int
  meltEnd : Int
  ordered : meltStart <= meltEnd

inductive FusionEquilibrium (d : FusionDiagram) (h : Int) : FusionPhase → Prop
  | solid (cold : h < d.meltStart) : FusionEquilibrium d h .solid
  | melting (lo : d.meltStart <= h) (hi : h < d.meltEnd) : FusionEquilibrium d h .melting
  | liquid (hot : d.meltEnd <= h) : FusionEquilibrium d h .liquid

@[macro_inline] def fusionPhase (d : FusionDiagram) (h : Int) : FusionPhase :=
  if h < d.meltStart then .solid else if h < d.meltEnd then .melting else .liquid

theorem fusion_phase_sound (d : FusionDiagram) (h : Int) :
    FusionEquilibrium d h (fusionPhase d h) := by
  unfold fusionPhase
  split
  · exact .solid (by assumption)
  · split
    · exact .melting (by omega) (by assumption)
    · exact .liquid (by omega)

theorem fusion_phase_complete (d : FusionDiagram) (h : Int) (r : FusionPhase)
    (spec : FusionEquilibrium d h r) : fusionPhase d h = r := by
  have ordered := d.ordered
  cases spec with
  | solid cold => simp [fusionPhase,cold]
  | melting lo hi => simp [fusionPhase,show ¬h < d.meltStart by omega,hi]
  | liquid hot => simp [fusionPhase,show ¬h < d.meltStart by omega,show ¬h < d.meltEnd by omega]

theorem fusion_phase_unique (d : FusionDiagram) (h : Int) (a b : FusionPhase)
    (ha : FusionEquilibrium d h a) (hb : FusionEquilibrium d h b) : a = b := by
  rw [← fusion_phase_complete d h a ha,← fusion_phase_complete d h b hb]

theorem fusion_phase_total (d : FusionDiagram) (h : Int) :
    ∃ r, FusionEquilibrium d h r ∧ ∀ s, FusionEquilibrium d h s → s = r :=
  ⟨_,fusion_phase_sound d h,fun _ spec => (fusion_phase_complete d h _ spec).symm⟩

def fusionRank : FusionPhase → Nat
  | .solid => 0 | .melting => 1 | .liquid => 2

theorem warming_cannot_reverse_fusion (d : FusionDiagram) (h q : Int) (a b : FusionPhase)
    (first : FusionEquilibrium d h a) (second : FusionEquilibrium d q b) (warmer : h <= q) :
    fusionRank a <= fusionRank b := by
  have ordered := d.ordered
  cases first <;> cases second <;> simp only [fusionRank] <;> omega

theorem executable_fusion_is_monotone (d : FusionDiagram) (h q : Int) (warmer : h <= q) :
    fusionRank (fusionPhase d h) <= fusionRank (fusionPhase d q) :=
  warming_cannot_reverse_fusion d h q _ _ (fusion_phase_sound _ _) (fusion_phase_sound _ _) warmer

end Sand2
