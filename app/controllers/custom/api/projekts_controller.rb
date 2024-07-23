class Api::ProjektsController < Api::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :find_projekt, only: [:update, :create_content_block, :destroy_content_block, :update_content_block, :update_content_block_position]
  before_action :process_tags, only: [:update]

  skip_authorization_check
  skip_forgery_protection

  def index
    projekts = Projekt.current_for_import.regular

    projekts.each(&:generate_page_view_code_if_nedded!)

    render json: {
      projekts: projekts.map(&:serialize)
    }
  end

  def create
    projekt = Projekt.new

    if save_projekt(projekt: projekt, projekt_params: projekt_params)
      render json: {
        projekt: projekt.serialize,
        message: "Projekt created"
      }
    else
      render json: { message: "Error updating projekt" }
    end
  end

  def import_projekt_params
    if save_projekt(projekt: @projekt, projekt_params: projekt_params)
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

  def create_content_block
    @content_block = @projekt.content_blocks.build(
      name: "custom",
      body: params[:html],
      key: "projekt_content_block_#{@projekt.id}_#{@projekt.content_blocks.count + 1}_#{DateTime.now.to_i}",
      locale: "de"
    )

    if @content_block.save
      if params[:previous_content_block_id].present?
        @previous_content_block = @projekt.content_blocks.find(params[:previous_content_block_id])
        @content_block.insert_at(@previous_content_block.position + 1)
      else
        @content_block.move_to_top
      end

      render json: { content_block: {id: @content_block.id}, status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content_block" }
    end
  end

  def update_content_block
    # TODO add authorization
    content_block = @projekt.content_blocks.find(params[:content_block_id])

    if content_block.update(body: params[:html])
      render json: { status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content_block" }
    end
  end

  def destroy_content_block
    @content_block = @projekt.content_blocks.find(params[:content_block_id])

    if @content_block.destroy
      render json: { status: { message: "Content block destroyed" }}
    else
      render json: { message: "Error destroying content_block" }
    end
  end

  def update_content_block_position
    content_block = @projekt.content_blocks.find(params[:content_block_id])

    if content_block.insert_at(params[:position].to_i)
      render json: { status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content_block" }
    end
  end

  private

  def find_projekt
    @projekt = Projekt.find(params[:id])
  end

  def save_projekt(projekt:, projekt_params:)
    Projekts::ImportService.call(
      projekt: projekt, projekt_params: projekt_params
    )
  end

  def projekt_params
    params.require(:projekt).permit(
      :name, :parent_id, :total_duration_start, :total_duration_end, :color, :icon,
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
    params.permit(
      :name, :parent_id, :total_duration_start, :total_duration_end, :color, :icon,
      :show_start_date_in_frontend, :show_end_date_in_frontend,
      :geozone_affiliated, :tag_list, :related_sdg_list,

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
      timeline: [:title, :description, :daterange],
      faq: [:title, :text],
      images: [],
      documents: [],

      geozone_affiliation_ids: [], sdg_goal_ids: [],
      individual_group_value_ids: [],
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
