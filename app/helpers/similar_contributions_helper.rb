module SimilarContributionsHelper
  def similar_contributions_badge(count, popup_url: nil)
    return if count.to_i.zero?

    label = t("components.similar_contributions.badge", count: count)

    tag.span(class: "similar-contributions-badge-wrapper", data: popup_data(popup_url)) do
      badge = tag.span(class: "similar-contributions-badge", tabindex: 0) do
        tag.span("difference", class: "material-symbols-outlined", aria: { hidden: true }) +
          tag.span(label)
      end

      next badge if popup_url.blank?

      badge + tag.span(
        class: "similar-contributions-badge--popup",
        data: { "adm--similar-contributions-popup-target": "popup" },
        hidden: true
      )
    end
  end

  # A counts hash is authoritative once it exists -- StoredCounts omits the
  # contributions with no set, and falling back per row would put a query
  # behind every title in the table.
  def similar_contributions_count_for(counts, resource)
    return counts[resource.id].to_i if counts.is_a?(Hash)

    resource.similar_contributions_peers_count
  end

  def similar_contributions_path_for(resource)
    return budget_investment_path(resource.budget, resource) if resource.is_a?(::Budget::Investment)

    proposal_path(resource)
  end

  def similar_contributions_excerpt(resource, words:)
    SimilarContributions::SearchTerms
      .strip_html(resource.description)
      .squish
      .truncate_words(words)
  end

  private

    def popup_data(popup_url)
      return {} if popup_url.blank?

      {
        controller: "adm--similar-contributions-popup",
        "adm--similar-contributions-popup-url-value": popup_url,
        action: "mouseenter->adm--similar-contributions-popup#open " \
                "mouseleave->adm--similar-contributions-popup#close " \
                "focusin->adm--similar-contributions-popup#open " \
                "focusout->adm--similar-contributions-popup#close"
      }
    end
end
