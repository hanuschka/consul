module SuggestionsHelper
  def suggest_data(record)
    # Not all models have projekt_phase_id (e.g. Budget::Investment), so check before calling
    projekt_phase_id = record.respond_to?(:projekt_phase_id) ? record.projekt_phase_id : nil

    return unless record.new_record? || projekt_phase_id.present?
    return if SimilarContributions::Scopes.enabled_for_resource?(record)

    {
      js_suggest_result: "js_suggest_result",
      js_suggest: ".js-suggest",
      js_url: polymorphic_path(record.class, action: :suggest),
      js_projekt_phase_id: projekt_phase_id,
      js_exclude_resource_id: record.persisted? ? record.id : nil
    }
  end
end
