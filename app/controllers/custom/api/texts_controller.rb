class Api::TextsController < Api::BaseController
  before_action :find_projekt_phase, only: [:index]

  def index
    check_read_access!
    texts = @projekt_phase.legislation_processes
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
end
