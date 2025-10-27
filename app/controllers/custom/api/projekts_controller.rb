class Api::ProjektsController < Api::BaseController
  include MapLocationAttributes
  include ImageAttributes
  include Translatable

  before_action :find_projekt, only: [:show, :update, :destroy]

  def index
    projekts =
      Projekt
        .activated
        .with_published_custom_page
        .show_in_overview_page
        .regular

    serailized_projekts = ProjektSerializer.serialize_collection(projekts)

    render json: { data: { projekts: serailized_projekts } }
  end

  def show
    serailized_projekt = ProjektSerializer.new(@projekt).serialize

    render json: { data: { projekt: serailized_projekt } }
  end

  def create
    projekt = Projekt.new(projekt_params)

    if projekt.save
      Projekt.ensure_order_integrity

      serailized_projekt = ProjektSerializer.new(projekt).serialize

      render json: { data: { projekt: serailized_projekt } }, status: 201
    else
      render json: { error: { messages: projekt.errors.messages }}, status: 422
    end
  end

  def update
    if @projekt.update(projekt_params)
      Projekt.ensure_order_integrity

      serailized_projekt = ProjektSerializer.new(@projekt).serialize

      render json: { data: { projekt: serailized_projekt } }
    else
      render json: { error: { messages: @projekt.errors.messages }}, status: 422
    end
  end

  def destroy
    if @projekt.destroy
      @projekt.children.each do |child|
        child.update(parent: nil)
      end

      render json: { message: "Projekt destroyed"}
    else
      render json: { error: { messages: @projekt.errors.messages  } }, status: 422
    end
  end

  private

  def projekt_params
    attributes = [
      :name, :parent_id, :total_duration_start, :total_duration_end,
      :show_start_date_in_frontend, :show_end_date_in_frontend,
      :geozone_affiliated, :order_number, :tag_list, :related_sdg_list, landing_page_ids: [], geozone_affiliation_ids: [], sdg_goal_ids: [],
      individual_group_value_ids: [],
      map_location_attributes: map_location_attributes,
      image_attributes: image_attributes,
      projekt_manager_assignments_attributes: [:id, :projekt_manager_id, :projekt_id, permissions: []]
    ]
    params.require(:projekt).permit(attributes, translation_params(Projekt))
  end

  def projekt_page_params
    params.require(:site_customization_page).permit(
      :title, :subtitle, :image
    )
  end

  def process_tags
    if params[:projekt].present?
      params[:projekt][:tag_list] = (params[:projekt][:tag_list_predefined] || @projekt.tag_list.join(","))
      params[:projekt].delete(:tag_list_predefined)
    end
  end

  def map_location_params
    params.require(:projekt)
      .require(:map_location_attributes)
      .permit(map_location_attributes)
  end

  def find_projekt
    @projekt = Projekt.find(params[:id])
  end
end
