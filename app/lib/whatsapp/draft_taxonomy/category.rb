class Whatsapp::DraftTaxonomy::Category
  # The catalog's "Category: Green spaces". This portal already has the concept
  # twice over — ProjektLabel, configured per phase and offered to the drafting
  # model as a closed enum, and the free-form tag_list the same call returns —
  # so nothing new is introduced here. This policy only answers which of the
  # two a given phase is using, so the draft can print one line either way.
  #
  # ProjektLabel is preferred wherever the phase enables it: it is curated by
  # the projekt's own team and the model can only choose from it, whereas
  # tag_list is whatever the model wrote.
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def kind
    :category
  end

  def key
    "projekt_label_ids"
  end

  # Gated on the phase's own predicate rather than on feature?("form.labels")
  # alone, because that is the one Labelable's create validation reads. A phase
  # using masterportal collections as labels requires one while the feature
  # flag is off — asked with the flag alone, the question would come back with
  # no options to offer and the draft would never be written.
  def required?
    @projekt_phase.present? && @projekt_phase.labels_selector_available?
  end

  def options
    return [] if !required?

    @projekt_phase.active_projekt_labels.includes(:translations).to_a
  end

  # The ids the drafting model returned, narrowed to the ones this phase
  # actually offers. Re-checked here for the same reason #assign! re-checks a
  # tapped pill: an id the model invented, or one since removed from the phase,
  # must not reach the record.
  def valid_ids(draft_data)
    ids = Array(draft_data["projekt_label_ids"]).map(&:to_i).reject(&:zero?)

    return [] if ids.empty? || !required?

    @projekt_phase.active_projekt_labels.where(id: ids).ids
  end

  def satisfied_by?(draft_data)
    !required? || valid_ids(draft_data).any?
  end

  # Labelable validates on create, so a draft written before the flow asked
  # for a label can still be sitting on a record without one.
  def missing_on?(resource)
    return false if !resource.respond_to?(:projekt_labels)

    required? && resource.projekt_labels.empty?
  end

  # A tapped answer, in the same shape the drafting model returns, so it is
  # re-read by exactly the validation that rejected the model's.
  def stash_for(option_id)
    { "projekt_label_ids" => [option_id.to_i] }
  end

  # Re-validated against the phase rather than trusted from the tapped pill: a
  # label id from a card sent days ago may since have been removed from the
  # phase. Saves, because the record it corrects already exists.
  def assign!(resource, option_id)
    return false if !required?

    label = @projekt_phase.active_projekt_labels.find_by(id: option_id)

    return false if label.blank?

    resource.projekt_label_ids = [label.id]
    resource.save!

    true
  end

  # Valid answers only, and no save — PersistDraftService owns the single
  # save!. A requirement the data does not satisfy is left alone rather than
  # cleared: on a revision the citizen's own earlier choice is already on the
  # record, and a rewrite of the text is not a reason to throw it away.
  def apply_to(resource, draft_data)
    label_ids = valid_ids(draft_data)

    return if label_ids.empty?

    resource.projekt_label_ids = label_ids
  end

  # Nil when the draft carries no category at all, which is what makes the
  # explicit C15 question worth asking.
  #
  # Gated on the resource's own phase. Without it a phase with labels switched
  # off still printed a "Category:" line built from whatever free-form tag the
  # model happened to write — a category the projekt's team never defined and
  # the citizen was never offered a way to change.
  def display_name(resource)
    return if resource.blank?
    return if !resource.projekt_phase&.labels_selector_available?

    chosen = chosen_label(resource)

    return chosen.name if chosen.present?

    resource.tag_list.to_a.first.presence
  end

  private

    def chosen_label(resource)
      return if !resource.respond_to?(:projekt_labels)

      resource.projekt_labels.first
    end
end
