class Whatsapp::DraftTaxonomy::Sentiment
  # The phase's sentiment scale — "supportive / neutral / critical" and the
  # like — which Sentimentable turns into a create-time requirement wherever
  # the phase enables it.
  #
  # The bot used to write past that requirement, so a draft the drafting model
  # gave no sentiment published without one, in a state the web form rejects
  # outright. Nothing on this path saves unvalidated any more, so this policy
  # is what makes the record writable at all — the same way Category asks for
  # a category the model did not choose.
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def kind
    :sentiment
  end

  def key
    "sentiment_id"
  end

  def required?
    return false if @projekt_phase.blank?
    return false if !@projekt_phase.feature?("form.sentiments")

    @projekt_phase.sentiments.exists?
  end

  def options
    return [] if !required?

    @projekt_phase.sentiments.includes(:translations).to_a
  end

  # The id the drafting model returned, as a list for interface parity with
  # Category — empty when this phase does not offer it, or when the model
  # answered outside the offered set.
  def valid_ids(draft_data)
    sentiment_id = draft_data["sentiment_id"].to_i

    return [] if sentiment_id.zero? || !required?
    return [] if !@projekt_phase.sentiments.exists?(id: sentiment_id)

    [sentiment_id]
  end

  def satisfied_by?(draft_data)
    !required? || valid_ids(draft_data).any?
  end

  # Both resources the bot drafts — Proposal and Budget::Investment — include
  # Sentimentable, so there is nothing to guard against beyond a missing draft.
  def missing_on?(resource)
    return false if resource.blank?

    required? && resource.sentiment_id.blank?
  end

  def stash_for(option_id)
    { "sentiment_id" => option_id.to_i }
  end

  # Re-validated against the phase rather than trusted from the tapped pill,
  # for the same reason Category does it: a sentiment id from a card sent days
  # ago may since have been removed from the phase.
  def assign!(resource, option_id)
    return false if !required?

    sentiment = @projekt_phase.sentiments.find_by(id: option_id)

    return false if sentiment.blank?

    resource.sentiment_id = sentiment.id
    resource.save!

    true
  end

  def apply_to(resource, draft_data)
    sentiment_id = valid_ids(draft_data).first

    return if sentiment_id.blank?

    resource.sentiment_id = sentiment_id
  end

  def display_name(resource)
    return if resource.blank?

    resource.sentiment&.name
  end
end
