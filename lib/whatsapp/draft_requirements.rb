module Whatsapp::DraftRequirements
  # What the resource's own on-create validations demand, asked of the drafting
  # model's output before any record exists.
  #
  # Labelable and Sentimentable both validate `on: :create`, so they run exactly
  # once — at the first save — and nothing later can make an invalid record
  # valid. The bot used to write straight past them with validate: false, which
  # is how a proposal with no label reached the portal in a state the web form
  # rejects outright. Now the draft stays in the conversation's context until
  # everything those validations need is in hand.
  #
  # The drafting model is handed both as closed enums and required to answer, so
  # this is the exception rather than a step: it catches an id that came back
  # outside the phase's own set.

  module_function

  def missing(draft_data, projekt_phase)
    return :category if missing_label?(draft_data, projekt_phase)
    return :sentiment if missing_sentiment?(draft_data, projekt_phase)

    nil
  end

  def missing_label?(draft_data, projekt_phase)
    return false if projekt_phase.blank?
    return false if !projekt_phase.labels_selector_available?

    valid_label_ids(draft_data, projekt_phase).empty?
  end

  # Re-checked against the phase rather than trusted from the model, for the
  # same reason DraftCategory re-checks a tapped pill: an id it invented, or one
  # since removed from the phase, must not reach the record.
  def valid_label_ids(draft_data, projekt_phase)
    ids = Array(draft_data["projekt_label_ids"]).map(&:to_i).reject(&:zero?)

    return [] if ids.empty?

    projekt_phase.active_projekt_labels.where(id: ids).ids
  end

  def missing_sentiment?(draft_data, projekt_phase)
    return false if !Whatsapp::DraftSentiment.required?(projekt_phase)

    valid_sentiment_id(draft_data, projekt_phase).blank?
  end

  def valid_sentiment_id(draft_data, projekt_phase)
    sentiment_id = draft_data["sentiment_id"].to_i

    return if sentiment_id.zero?
    return if !projekt_phase.sentiments.exists?(id: sentiment_id)

    sentiment_id
  end
end
