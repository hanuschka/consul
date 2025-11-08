class Api::TextsController < Api::BaseController
  before_action :find_projekt_phase, only: [:index]

  def index
    check_read_access!
    legislation_process = @projekt_phase.legislation_process
    return render json: { data: { texts: [] }, pagination: default_pagination_meta } unless legislation_process

    texts = legislation_process.draft_versions
      .page(params[:page])
      .per(params[:per_page] || 100)

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

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end

  def default_pagination_meta
    {
      current_page: 1,
      total_pages: 0,
      total_count: 0,
      per_page: params[:per_page] || 100
    }
  end
end
