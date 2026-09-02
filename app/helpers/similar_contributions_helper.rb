module SimilarContributionsHelper
  def similar_contributions_badge(count)
    return if count.to_i.zero?

    tag.span(class: "similar-contributions-badge",
             title: t("components.similar_contributions.badge", count: count)) do
      tag.span("difference", class: "material-symbols-outlined", aria: { hidden: true }) +
        tag.span(count)
    end
  end

  def similar_contributions_count_for(counts, resource)
    return counts[resource.id].to_i if counts.is_a?(Hash) && counts.key?(resource.id)

    SimilarContributions::CandidateCounts.call([resource]).fetch(resource.id, 0)
  end
end
