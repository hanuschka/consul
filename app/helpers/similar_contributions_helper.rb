module SimilarContributionsHelper
  def similar_contributions_badge(count, popup_url: nil, url: nil)
    return if count.to_i.zero?

    label = t("components.similar_contributions.badge", count: count)

    tag.span(class: "similar-contributions-badge-wrapper", data: popup_data(popup_url)) do
      badge = similar_contributions_badge_body(label, url)

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

  # The contribution's own backend page. The phase comes from the match itself,
  # never from the contribution currently open -- a stored set spans every phase
  # of the projekt, so the open one would send half the rows to the wrong phase.
  def similar_contributions_backend_path_for(resource)
    projekt_phase = SimilarContributions::Scopes.projekt_phase_of(resource)

    return if projekt_phase.blank?

    if resource.is_a?(::Budget::Investment)
      adm_projekts_phase_budget_investment_path(projekt_phase, resource)
    else
      adm_projekts_phase_proposal_path(projekt_phase, resource)
    end
  end

  # Whether this user may actually open that page, so a Sachbearbeiter is never
  # offered a link they are then refused -- the two classes disagree on who may
  # read a contribution, and only the proposal page admits a moderator.
  #
  # Every match of a set sits in the same projekt, and the policies decide per
  # projekt, so the answer is one boolean for a whole list. Memoised per set
  # rather than per row, which would repeat the same assignment lookup N times.
  def similar_contributions_backend_permitted?(resource)
    projekt = SimilarContributions::Scopes.projekt_phase_of(resource)&.projekt

    return false if projekt.blank?

    permissions = (@similar_contributions_backend_permissions ||= {})
    key = [resource.class.base_class.name, projekt.id]

    return permissions[key] if permissions.key?(key)

    permissions[key] = similar_contributions_backend_policy_for(resource).show?
  end

  def similar_contributions_excerpt(resource, words:)
    SimilarContributions::SearchTerms
      .strip_html(resource.description)
      .squish
      .truncate_words(words)
  end

  private

    # The adm pages authorise a budget investment through the projekt's budget
    # policy and a proposal through its own, so the class a row belongs to also
    # decides which policy answers for it.
    def similar_contributions_backend_policy_for(resource)
      if resource.is_a?(::Budget::Investment)
        return Adm::Projekts::BudgetPolicy.new(current_user, resource)
      end

      Adm::ProposalPolicy.new(current_user, resource)
    end

    # The index badge is a link wherever the contribution has an admin page to
    # jump to, so the hover panel is a preview rather than the only way in.
    def similar_contributions_badge_body(label, url)
      content = tag.span("difference", class: "material-symbols-outlined", aria: { hidden: true }) +
        tag.span(label)

      return tag.span(content, class: "similar-contributions-badge", tabindex: 0) if url.blank?

      link_to content, url, class: "similar-contributions-badge",
                            data: { turbo_frame: "_top" }
    end

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
