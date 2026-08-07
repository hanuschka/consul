module Whatsapp::DraftSentiment
  # The phase's sentiment scale — "supportive / neutral / critical" and the like
  # — which Sentimentable turns into a create-time requirement wherever the
  # phase enables it.
  #
  # The bot used to write past that requirement, so a draft the drafting model
  # gave no sentiment published without one, in a state the web form rejects
  # outright. Nothing on this path saves unvalidated any more, so the question
  # below is what makes the record writable at all — the same way DraftCategory
  # asks for a category the model did not choose.
  MAX_CHOICE_BUTTONS = 3

  module_function

  def required?(projekt_phase)
    return false if projekt_phase.blank?
    return false if !projekt_phase.feature?("form.sentiments")

    projekt_phase.sentiments.exists?
  end

  def options_for(projekt_phase)
    return [] if !required?(projekt_phase)

    projekt_phase.sentiments.includes(:translations).to_a
  end

  # Both resources the bot drafts — Proposal and Budget::Investment — include
  # Sentimentable, so there is nothing to guard against beyond a missing draft.
  def missing?(resource, projekt_phase)
    return false if resource.blank?

    required?(projekt_phase) && resource.sentiment_id.blank?
  end

  def label_for(resource)
    return if resource.blank?

    resource.sentiment&.name
  end

  # Re-validated against the phase rather than trusted from the tapped pill, for
  # the same reason DraftCategory does it: a sentiment id from a card sent days
  # ago may since have been removed from the phase.
  def assign(resource, projekt_phase, sentiment_id)
    return false if !required?(projekt_phase)

    sentiment = projekt_phase.sentiments.find_by(id: sentiment_id)

    return false if sentiment.blank?

    resource.sentiment_id = sentiment.id
    resource.save!

    true
  end
end
