module Whatsapp::DraftCategory
  # The catalog's "Category: Green spaces". This portal already has the concept
  # twice over — ProjektLabel, configured per phase and offered to the drafting
  # model as a closed enum, and the free-form tag_list the same call returns —
  # so nothing new is introduced here. This module only answers which of the two
  # a given phase is using, so the draft can print one line either way.
  #
  # ProjektLabel is preferred wherever the phase enables it: it is curated by
  # the projekt's own team and the model can only choose from it, whereas
  # tag_list is whatever the model wrote.
  MAX_CHOICE_BUTTONS = 3

  module_function

  # Gated on the phase's own predicate rather than on feature?("form.labels")
  # alone, because that is the one Labelable's create validation reads. A phase
  # using masterportal collections as labels requires one while the feature flag
  # is off — asked with the flag alone, the question would come back with no
  # options to offer and the draft would never be written.
  def options_for(projekt_phase)
    return [] if projekt_phase.blank?
    return [] if !projekt_phase.labels_selector_available?

    projekt_phase.active_projekt_labels.includes(:translations).to_a
  end

  # Nil when the draft carries no category at all, which is what makes the
  # explicit C15 question worth asking.
  #
  # Gated on the same predicate as options_for. Without it a phase with labels
  # switched off still printed a "Category:" line built from whatever free-form
  # tag the model happened to write — a category the projekt's team never
  # defined and the citizen was never offered a way to change.
  def label_for(resource)
    return if resource.blank?
    return if !resource.projekt_phase&.labels_selector_available?

    chosen = chosen_label(resource)

    return chosen.name if chosen.present?

    resource.tag_list.to_a.first.presence
  end

  def chosen_label(resource)
    return if !resource.respond_to?(:projekt_labels)

    resource.projekt_labels.first
  end

  # Re-validated against the phase rather than trusted from the tapped pill: a
  # label id from a card sent days ago may since have been removed from the
  # phase.
  def assign(resource, projekt_phase, label_id)
    return false if projekt_phase.blank? || !projekt_phase.labels_selector_available?

    label = projekt_phase.active_projekt_labels.find_by(id: label_id)

    return false if label.blank?

    resource.projekt_label_ids = [label.id]
    resource.save!

    true
  end
end
