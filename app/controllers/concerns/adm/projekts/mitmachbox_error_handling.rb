module Adm::Projekts::MitmachboxErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from Mitmachbox::Error, with: :handle_mitmachbox_error
    helper_method :mitmachbox_error_message
  end

  private

    def mitmachbox_client
      Mitmachbox::Client.new(acting_user: current_user)
    end

    def mitmachbox_fetch_all(per_page: 200, max_pages: 25)
      records = []
      page = 1

      loop do
        result = yield(page, per_page)
        records.concat(result["data"])
        break if page >= result.dig("meta", "total_pages").to_i || page >= max_pages

        page += 1
      end

      records
    end

    def handle_mitmachbox_error(error)
      # Never redirect_back: when the failure originates in a tab GET's
      # before_action (e.g. set_survey_and_draft), the Referer is that same
      # tab, and the browser carries it across the 302 — an API outage would
      # loop until ERR_TOO_MANY_REDIRECTS. Redirect to a tab whose action
      # rescues API errors inline and renders them.
      redirect_to mitmachbox_error_redirect_path, alert: mitmachbox_error_message(error)
    end

    # Overridable per controller; defaults to the survey tab (its GET action
    # rescues Mitmachbox::Error inline, so it renders rather than re-raises).
    def mitmachbox_error_redirect_path
      mitmachbox_survey_adm_projekts_phase_path(@projekt_phase)
    end

    def mitmachbox_error_message(error)
      case error
      when Mitmachbox::ConnectionError
        t("adm.projekts.mitmachbox.errors.connection")
      when Mitmachbox::AuthError
        t("adm.projekts.mitmachbox.errors.auth")
      when Mitmachbox::ForbiddenError
        t("adm.projekts.mitmachbox.errors.forbidden")
      when Mitmachbox::NotFoundError
        t("adm.projekts.mitmachbox.errors.not_found")
      when Mitmachbox::ConflictError
        t("adm.projekts.mitmachbox.errors.conflict", message: error.api_message)
      when Mitmachbox::ValidationError
        t("adm.projekts.mitmachbox.errors.validation", message: error.api_message)
      else
        t("adm.projekts.mitmachbox.errors.generic")
      end
    end
end
