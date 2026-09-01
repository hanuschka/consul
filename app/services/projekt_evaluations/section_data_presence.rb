module ProjektEvaluations::SectionDataPresence
  def self.has_data?(phase_data, section_key)
    full = phase_data["full_stats"] || {}
    any_positive = ->(data) { ((data || {})["values"] || []).any? { |value| value.to_i > 0 } }

    case section_key.to_s
    when "timeline"
      (full["timeline"] || {})["total_submissions"].to_i > 0
    when "label_sentiment"
      label_sentiment = full["label_sentiment"] || {}

      any_positive.call(label_sentiment["labels"]) || any_positive.call(label_sentiment["sentiments"])
    when "user_segments"
      segments = full["user_segments"] || {}

      any_positive.call(segments["gender"]) ||
        any_positive.call(segments["age"]) ||
        any_positive.call(segments["geozone"]) ||
        (segments["individual_groups"] || []).any? { |group| any_positive.call(group) }
    when "heatmap"
      ((full["heatmap"] || {})["coordinates"] || []).any?
    when "ranking"
      ((phase_data["stats"] || {})["top_proposals"] || []).any?
    when "topic_clustering", "semantic_clustering"
      clustering = (phase_data["ai_stats"] || {})[section_key.to_s] || {}
      categories = clustering.is_a?(Array) ? clustering : clustering.values

      categories.any?
    else
      true
    end
  end
end
