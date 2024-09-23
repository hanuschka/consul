class Api::ProjektsController < Api::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :find_projekt, only: [
    :update, :import
  ]
  before_action :process_tags, only: [:update]

  skip_authorization_check
  skip_forgery_protection

  def index
    projekts = Projekt.current_for_import.regular

    projekts.each(&:generate_preview_code_if_nedded!)
    projekts.each(&:generate_frame_access_code_if_nedded!)

    render json: {
      projekts: projekts.map(&:serialize)
    }
  end

  def overview
    projekts =
      Projekt
        .activated
        .with_published_custom_page
        .show_in_overview_page
        .regular
        .includes(:page, :projekt_phases, :map_location)

    render json: {
      projekts: projekts.map { |projekt|
        Projekts::SerializeForOverview.call(projekt)
      }
    }
  end

  def create
    projekt = Projekt.new

    if import_projekt(projekt: projekt)
      render json: {
        projekt: projekt.serialize,
        message: "Projekt created"
      }
    else
      render json: { message: "Error updating projekt" }
    end
  end

  def import
    if import_projekt(projekt: @projekt)
      render json: { projekt: @projekt.serialize, status: { message: "Projekt updated" }}
    else
      render json: { message: "Error updating projekt" }
    end
  end

  def update
    if @projekt.update(projekt_params)
      render json: { projekt: @projekt.serialize, status: { message: "Projekt updated" }}
    else
      render json: { message: "Error updating projekt" }
    end
  end


  private

  def find_projekt
    @projekt = Projekt.find(params[:id])
  end

  def import_projekt(projekt:)
    Projekts::ImportService.call(
      projekt: projekt, projekt_params: import_projekt_params
    )
  end

  def projekt_params
    params.require(:projekt).permit(
      :title, :parent_id, :total_duration_start, :total_duration_end, :color, :icon,
      :show_start_date_in_frontend, :show_end_date_in_frontend,
      :geozone_affiliated, :tag_list, :related_sdg_list,

      geozone_affiliation_ids: [],
      sdg_goal_ids: [],
      individual_group_value_ids: [],
      map_location_attributes: map_location_attributes,
      image_attributes: image_attributes,
      projekt_notifications: [:title, :body],
      project_events: [:id, :title, :location, :datetime, :weblink],
      projekt_manager_assignments_attributes: [:id, :projekt_manager_id, :projekt_id, permissions: []],
    )
  end

  def import_projekt_params
    params.require(:projekt).permit(
      :title,
      :brief_description,
      :summary,
      :greeting,
      :additional_information,
      :page_content,
      :greeting_title,
      :greeting_quote,
      :greeting_accordion_title,
      :summary_title,
      :contact_information,
      :start_date, :end_date,
      :show_map, :show_navigator_in_projekts_page_sidebar,
      :show_notification_subscription_toggler,
      :show_phases_in_projekt_page_sidebar,
      :projekt_page_sharing,
      :title_image,
      :greeting_image,
      images: [],
      documents: [],
      geozone_affiliation_ids: [], sdg_goal_ids: [],
      individual_group_value_ids: [],
      timeline: [:title, :description, :daterange],
      faq: [:title, :text],
      map_location_attributes: map_location_attributes,
      image_attributes: image_attributes,
      projekt_notifications: [:title, :body],
      project_events: [:id, :title, :location, :datetime, :weblink],
      projekt_manager_assignments_attributes: [:id, :projekt_manager_id, :projekt_id, permissions: []],
    )
  end

  def process_tags
    if params[:projekt].present? && params[:projekt][:tag_list_predefined].present?
      params[:projekt][:tag_list] = (params[:projekt][:tag_list_predefined] || @projekt.tag_list.join(","))
      params[:projekt].delete(:tag_list_predefined)
    end
  end

  def map_location_params
    if params[:map_location]
      params.require(:map_location).permit(map_location_attributes)
    else
      params.permit(map_location_attributes)
    end
  end
end
