class InternalApi::ProjektImportReferencesController < InternalApi::BaseController
  skip_authorization_check

  def show
    render json: {
      tags: fetch_tags,
      sdg_goals: fetch_sdg_goals,
      phase_types: ProjektPhase::PROJEKT_PHASES_TYPES,
      projekt_settings: ProjektSetting.defaults,
      projekt_phase_settings: ProjektPhaseSetting.defaults
    }
  end

  private

  def fetch_tags
    Tag
      .order("taggings_count DESC NULLS LAST")
      .limit(50)
      .pluck(:name)
  end

  def fetch_sdg_goals
    SDG::Goal.order(:code).map do |goal|
      { code: goal.code.to_s, title: goal.title }
    end
  end
end
