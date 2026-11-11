class Api::Configuration::GeozonesController < Api::Configuration::BaseController
  # Every table pointing at a geozone through a geozone_id column, hidden
  # records included: deleting a geozone they still name would orphan them.
  REFERENCING_MODELS = [
    User, Debate, Proposal, Legislation::Proposal, Poll::Voter, GeozonesPoll, ProjektPhaseGeozone
  ].freeze

  MAP_COORDINATES_FORMAT = /\A\s*\d+(\s*,\s*\d+)*\s*\z/
  IN_USE_MESSAGE = "is still used by users, contributions, polls, projekts or phases".freeze

  before_action :find_geozone, only: [:show, :update, :destroy]

  def index
    geozones = paginate(Geozone.order(:id))

    render json: {
      data: { geozones: geozones.map { serialize(it) } },
      pagination: pagination_meta(geozones)
    }
  end

  def show
    render json: { data: { geozone: serialize(@geozone) } }
  end

  def create
    geozone = Geozone.new(geozone_params)

    if invalid_map_coordinates?(geozone)
      return render_invalid_values("html_map_coordinates" => [map_coordinates_message])
    end

    if geozone.save
      render json: { data: { geozone: serialize(geozone) } }, status: :created
    else
      render_record_errors(geozone)
    end
  end

  def update
    @geozone.assign_attributes(geozone_params)

    if invalid_map_coordinates?(@geozone)
      return render_invalid_values("html_map_coordinates" => [map_coordinates_message])
    end

    if @geozone.save
      render json: { data: { geozone: serialize(@geozone) } }
    else
      render_record_errors(@geozone)
    end
  end

  def destroy
    if geozone_in_use?(@geozone)
      return render_invalid_values("geozone" => [IN_USE_MESSAGE])
    end

    @geozone.destroy!

    head :no_content
  end

  private

    def find_geozone
      @geozone = Geozone.find(params[:id])
    end

    # Census codes and postal codes drive verification, which the API leaves
    # alone, so they are neither written nor shown here.
    def geozone_params
      params.require(:geozone).permit(:name, :external_code, :html_map_coordinates)
    end

    def serialize(geozone)
      {
        id: geozone.id,
        name: geozone.name,
        external_code: geozone.external_code,
        html_map_coordinates: geozone.html_map_coordinates,
        created_at: geozone.created_at,
        updated_at: geozone.updated_at
      }
    end

    def invalid_map_coordinates?(geozone)
      geozone.html_map_coordinates.present? &&
        !geozone.html_map_coordinates.match?(MAP_COORDINATES_FORMAT)
    end

    def map_coordinates_message
      "must be a comma-separated list of whole numbers, such as 10,20,30,40"
    end

    def geozone_in_use?(geozone)
      referenced_by_column = REFERENCING_MODELS.any? do |model|
        model.unscoped.where(geozone_id: geozone.id).exists?
      end

      referenced_by_column ||
        Projekt.unscoped.joins(:geozone_affiliations).where(geozones: { id: geozone.id }).exists?
    end
end
