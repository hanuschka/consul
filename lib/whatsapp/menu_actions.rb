module Whatsapp::MenuActions
  # The central navigation. Ids are global the way the recovery ones are: a row
  # is answered before the step dispatcher and before the assistant, so tapping
  # it works from whatever state the conversation is in.
  ROW_IDS = {
    create: "whatsapp_menu_create",
    contributions: "whatsapp_menu_contributions",
    projekts: "whatsapp_menu_projekts",
    results: "whatsapp_menu_results"
  }.freeze

  # Second-level rows. Both lead to a link rather than to a state change, which
  # is why they share one handler and differ only in what they point at.
  PROJEKT_ROW_PREFIX = "whatsapp_open_projekt_".freeze
  RESULT_ROW_PREFIX = "whatsapp_open_result_".freeze

  module_function

  def action_from(row_id)
    ROW_IDS.key(row_id.to_s)
  end

  def projekt_row_id_for(projekt_id)
    "#{PROJEKT_ROW_PREFIX}#{projekt_id}"
  end

  def result_row_id_for(projekt_phase_id)
    "#{RESULT_ROW_PREFIX}#{projekt_phase_id}"
  end

  def projekt_id_from(row_id)
    id_from(row_id, PROJEKT_ROW_PREFIX)
  end

  def projekt_phase_id_from(row_id)
    id_from(row_id, RESULT_ROW_PREFIX)
  end

  def link_row?(row_id)
    projekt_id_from(row_id).present? || projekt_phase_id_from(row_id).present?
  end

  def id_from(row_id, prefix)
    return if row_id.to_s.blank?
    return if !row_id.to_s.start_with?(prefix)

    row_id.to_s.delete_prefix(prefix).to_i
  end
  private_class_method :id_from
end
