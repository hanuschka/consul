class Api::TextsController < Api::BaseController
  before_action :find_projekt_phase, only: [:index]

  def index
    check_read_access!
    legislation_process = @projekt_phase.legislation_process

    if legislation_process.blank?
      return render json: { data: { texts: [] }, pagination: empty_pagination_meta }
    end

    texts = paginate(legislation_process.draft_versions)

    serialized_texts = texts.map { |text| LegislationProcessSerializer.new(text).serialize }

    render json: {
      data: { texts: serialized_texts },
      pagination: pagination_meta(texts)
    }
  end

  private

  def find_projekt_phase
    @projekt_phase = ProjektPhase::LegislationPhase.find(params[:projekt_phase_id])
  end
end
