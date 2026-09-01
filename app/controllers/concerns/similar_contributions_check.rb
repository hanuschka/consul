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

      return false if !resource.save

      SimilarContributions::CheckJob.perform_later(resource)

      true
    end

    # The AJAX submission consumed the invisible_captcha timestamp, so without
    # a fresh one the corrected resubmission from the same page would be
    # flagged as spam and redirected away.
    def similar_contributions_invalid_payload(resource)
      session[:invisible_captcha_timestamp] = Time.zone.now.iso8601

      {
        status: "invalid",
        errors_html: render_to_string(
          partial: "shared/form_errors_summary",
          locals: { resource: resource },
          formats: [:html],
          layout: false
        )
      }
    end

    def similar_contributions_check_started_payload(resource)
      if resource.is_a?(::Budget::Investment)
        {
          status: "processing",
          status_url: similar_contributions_status_budget_investment_path(resource.budget, resource),
          publish_url: publish_draft_budget_investment_path(resource.budget, resource)
        }
      else
        {
          status: "processing",
          status_url: similar_contributions_status_proposal_path(resource),
          publish_url: publish_draft_proposal_path(resource)
        }
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
