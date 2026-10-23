class Mitmachbox::PublicSurveyService
  CACHE_TTL = 5.minutes

  def self.call(projekt_phase)
    new(projekt_phase).call
  end

  def self.cache_key(survey_id)
    "mitmachbox/public_survey/#{survey_id}"
  end

  def self.expire!(survey_id)
    Rails.cache.delete(cache_key(survey_id)) if survey_id.present?
  end

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    return if survey_id.blank? || !Mitmachbox.configured?

    Rails.cache.fetch(self.class.cache_key(survey_id), expires_in: CACHE_TTL) { fetch }
  rescue Mitmachbox::Error => e
    Rails.logger.warn("[Mitmachbox] public survey unavailable for phase #{@projekt_phase.id}: #{e.message}")
    nil
  end

  private

    def survey_id
      @projekt_phase.mitmachbox_survey_id
    end

    def fetch
      survey = client.surveys.find(survey_id)
      version_ref = survey["current_version"]
      return if version_ref.blank?

      detail = client.versions.find(survey["id"], version_ref["id"])

      {
        "state" => survey["state"],
        "survey_id" => survey["id"],
        "version_id" => version_ref["id"],
        "questions" => sorted_questions(detail)
      }
    end

    def sorted_questions(detail)
      (detail["questions"] || []).sort_by { |question| question["position"].to_i }.map do |question|
        question.merge(
          "options" => (question["options"] || []).sort_by { |option| option["position"].to_i }
        )
      end
    end

    def client
      @client ||= Mitmachbox::Client.new
    end
end
