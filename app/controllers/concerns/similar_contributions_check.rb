module SimilarContributionsCheck
  extend ActiveSupport::Concern

  private

    def similar_contributions_check_requested?(projekt_phase)
      return false if params[:skip_similarity_check].present?
      return false if params[:save_draft].present?

      SimilarContributions::Scopes.enabled_for?(projekt_phase) && Ai::Settings.ai_available?
    end

    # The contribution is parked as an unpublished draft so the job has a record
    # to write its status onto, and so the citizen's input -- uploads included --
    # survives until they publish or walk away.
    def start_similar_contributions_check(resource)
      resource.draft = true
      resource.similar_contributions_check_status = "processing"

      if resource.save
        SimilarContributions::CheckJob.perform_later(resource)
      end
    end

    def similar_contributions_status_payload(resource)
      payload = { status: resource.similar_contributions_check_status.to_s }
      return payload if !resource.similar_contributions_check_completed?

      matches = SimilarContributions::StoredMatches.call(resource)

      payload.merge(
        matches_count: matches.size,
        html: similar_contributions_notice_html(matches, resource)
      )
    end

    def similar_contributions_notice_html(matches, resource)
      return "" if matches.empty?

      render_to_string(
        SimilarContributions::NoticeComponent.new(matches, resource: resource),
        layout: false
      )
    end
end
