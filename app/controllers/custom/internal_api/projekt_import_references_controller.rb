class InternalApi::ProjektImportReferencesController < InternalApi::BaseController
  skip_authorization_check

  def show
    render json: {
      tags: fetch_tags,
      sdg_goals: fetch_sdg_goals,
      phase_types: ProjektPhase::PROJEKT_PHASES_TYPES,
      projekt_settings: ProjektSetting.defaults,
      projekt_phase_settings: ProjektPhaseSetting.defaults,
      poll_vote_types: VotationType.vote_types.keys,
      age_ranges: fetch_age_ranges,
      geozones: fetch_geozones,
      user_statuses: ProjektPhase.user_statuses.keys
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

  def fetch_age_ranges
    AgeRange.for_restrictions.map do |ar|
      { id: ar.id, name: ar.name, min_age: ar.min_age, max_age: ar.max_age }
    end
  end

  def fetch_geozones
    Geozone.all.map do |gz|
      { id: gz.id, name: gz.name }
    end
  end
end
