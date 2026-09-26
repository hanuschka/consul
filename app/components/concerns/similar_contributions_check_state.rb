module SimilarContributionsCheckState
  extend ActiveSupport::Concern

  def render?
    resource.present? && (check_processing? || check_available?)
  end

  def check_processing?
    resource.persisted? && resource.similar_contributions_check_processing?
  end

  private

    def check_available?
      ::SimilarContributions::Scopes.enabled_for_resource?(resource) &&
        ::Ai::Settings.ai_available?
    end
end
