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

  def available?(projekt_phase)
    options_for(projekt_phase).any?
  end

  def options_for(projekt_phase)
    return [] if projekt_phase.blank?
    return [] if !projekt_phase.feature?("form.labels")

    projekt_phase.projekt_labels.includes(:translations).to_a
  end

  # Nil when the draft carries no category at all, which is what makes the
  # explicit C15 question worth asking.
  def label_for(resource)
    return if resource.blank?

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
    label = options_for(projekt_phase).find { |option| option.id == label_id.to_i }

    return false if label.blank?

    resource.projekt_label_ids = [label.id]
    resource.save!(validate: false)

    true
  end
end
