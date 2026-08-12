module Whatsapp::PhaseListRows
  # One selectable row per open phase, titled by its projekt: a citizen
  # recognises the projekt, not the phase, while the tap has to carry the phase.
  #
  # Shared by the linked discovery list and the guest one. They differ only in
  # which phases they are handed, so the row shape lives here rather than being
  # written twice and drifting once.

  module_function

  def build(projekt_phases)
    projekt_phases.map do |projekt_phase|
      {
        id: Whatsapp::FlowActions.id_for(action: :idea_start, param: projekt_phase.id),
        title: Whatsapp::ProjektLink.title(projekt_phase.projekt),
        description: description_for(projekt_phase)
      }
    end
  end

  # `title` rather than `name`: a phase's name is its type identifier —
  # ProposalPhase#name returns the literal "proposal_phase" — while `title` is
  # the tab name an admin gave it, falling back to the model's human name.
  def description_for(projekt_phase)
    return projekt_phase.title if projekt_phase.end_date.blank?

    I18n.t(
      "whatsapp.bot.discovery.row_description",
      phase: projekt_phase.title,
      end_date: I18n.l(projekt_phase.end_date)
    )
  end
end
