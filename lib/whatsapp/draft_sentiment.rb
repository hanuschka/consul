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

  # Debates and budget investments carry the concern too, but a phase type the
  # bot has no flow for can never reach this — the respond_to? guard is for the
  # resource, not for the phase.
  def missing?(resource, projekt_phase)
    return false if resource.blank?
    return false if !resource.respond_to?(:sentiment_id)

    required?(projekt_phase) && resource.sentiment_id.blank?
  end

  def label_for(resource)
    return if resource.blank?
    return if !resource.respond_to?(:sentiment)

    resource.sentiment&.name
  end

  # Re-validated against the phase rather than trusted from the tapped pill, for
  # the same reason DraftCategory does it: a sentiment id from a card sent days
  # ago may since have been removed from the phase.
  def assign(resource, projekt_phase, sentiment_id)
    sentiment = options_for(projekt_phase).find { |option| option.id == sentiment_id.to_i }

    return false if sentiment.blank?

    resource.sentiment_id = sentiment.id
    resource.save!

    true
  end
end
