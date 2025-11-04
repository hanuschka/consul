class Api::ProjektsController < Api::BaseController
  include MapLocationAttributes
  include ImageAttributes
  include Translatable

  before_action :find_projekt, only: [:show, :update, :destroy, :update_setting, :update_image, :update_page, :update_body]

  def index
    check_read_access!
    projekts =
      Projekt
        .regular

    if params[:only_visible] == "true"
      projekts =
        projekt
          .activated
          .with_published_custom_page
          .show_in_overview_page
    end

    include_phases = params[:include_phases] != 'false'
    include_content_blocks = params[:include_content_blocks] != 'false'

    includes_hash = {}
    includes_hash[:content_blocks] = {} if include_content_blocks

    if include_phases
      includes_hash[:projekt_phases] = [
        :settings,
        :individual_group_values,
        :geozone_restrictions
      ]
    end

    projekts = projekts.includes(includes_hash) if includes_hash.any?

    serailized_projekts = ProjektSerializer.serialize_collection(
      projekts,
      include_phases: include_phases,
      include_content_blocks: include_content_blocks
    )

    render json: { data: { projekts: serailized_projekts } }
  end

  def show
    check_read_access!

    include_phases = params[:include_phases] != 'false'
    include_content_blocks = params[:include_content_blocks] != 'false'

    serailized_projekt = ProjektSerializer.new(
      @projekt,
      include_phases: include_phases,
      include_content_blocks: include_content_blocks
    ).serialize

    render json: { data: { projekt: serailized_projekt } }
  end

  def create
    check_admin_access!
    projekt = Projekt.new(projekt_params)

    if projekt.save
      Projekt.ensure_order_integrity

      create_default_content_block(projekt)

      serailized_projekt = ProjektSerializer.new(projekt).serialize

      render json: { data: { projekt: serailized_projekt } }, status: 201
    else
      render json: { error: { messages: projekt.errors.messages }}, status: 422
    end
  end

  def update
    check_admin_access!
    if @projekt.update(projekt_params)
      Projekt.ensure_order_integrity

      serailized_projekt = ProjektSerializer.new(@projekt).serialize

      render json: { data: { projekt: serailized_projekt } }
    else
      render json: { error: { messages: @projekt.errors.messages }}, status: 422
    end
  end

  def update_page
    check_admin_access!
    if @projekt.page.update(projekt_page_params)
      serailized_projekt = ProjektSerializer.new(@projekt).serialize

      render json: { data: { projekt: serailized_projekt } }
    else
      render json: { error: { messages: @projekt.page.errors.full_messages } }, status: 422
    end
  end

  def update_image
    check_admin_access!
    page = @projekt.page
    image_attrs = params.require(:image).permit(*image_attributes_api)

    if ActiveModel::Type::Boolean.new.cast(image_attrs[:_destroy])
      page.image&.destroy
      page.image = nil
      page.save!
    elsif image_attrs[:attachment].present?
      update_image_with_attachment(page, image_attrs)
    elsif page.image.present?
      page.image.update!(image_attrs.except(:_destroy, :attachment))
    end

    serialized_projekt = ProjektSerializer.new(@projekt).serialize
    render json: { data: { projekt: serialized_projekt } }
  rescue Api::BaseController::ForbiddenError, Api::BaseController::UnauthorizedError
    raise # Re-raise to let base controller handle it
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update_image_with_attachment(page, image_attrs)
    attachment_data = image_attrs[:attachment]
    temp_file = Base64ImageUtils.decode_to_tempfile(attachment_data)
    content_type = Base64ImageUtils.content_type_from_string(attachment_data)
    filename = "image.#{Base64ImageUtils.extension_from_content_type(content_type)}"

    user = User.administrators.first
    raise StandardError, "No user available to associate with the image. Please ensure at least one user exists." unless user

    image_params = image_attrs.except(:_destroy, :attachment).merge(user: user)

    if page.image.present?
      image = page.image
      image.assign_attributes(image_params)
      image.attachment.attach(io: File.open(temp_file.path, 'rb'), filename: filename, content_type: content_type)
      image.save!
    else
      image = Image.new(image_params.merge(imageable: page))
      image.attachment.attach(io: File.open(temp_file.path, 'rb'), filename: filename, content_type: content_type)
      image.save!
      page.image = image
    end
  ensure
    temp_file&.close
    temp_file&.unlink
  end

  def destroy
    check_admin_access!
    if @projekt.destroy
      @projekt.children.each do |child|
        child.update(parent: nil)
      end

      render json: { message: "Projekt destroyed"}
    else
      render json: { error: { messages: @projekt.errors.messages  } }, status: 422
    end
  end

  def update_setting
    check_admin_access!
    setting = @projekt.projekt_settings.find_by(key: setting_params[:key])

    unless setting
      return render json: { error: { messages: ["Setting not found"] } }, status: 404
    end

    if setting.update(value: setting_params[:value])
      render json: {
        data: {
          setting: {
            id: setting.id,
            key: setting.key,
            value: setting.value,
            projekt_id: setting.projekt_id
          }
        },
        message: "Setting updated successfully"
      }
    else
      render json: { error: { messages: setting.errors.full_messages } }, status: 422
    end
  end

  def update_body
    check_admin_access!

    first_content_block = @projekt.content_blocks.order(:position).first

    unless first_content_block
      return render json: { error: { messages: ["No content block found for this project"] } }, status: 404
    end

    if first_content_block.update(content_block_body_params)
      serialized_content_block = ContentBlockSerializer.new(first_content_block).serialize

      render json: {
        data: { content_block: serialized_content_block },
        message: "Content block body updated successfully"
      }
    else
      render json: { error: { messages: first_content_block.errors.full_messages } }, status: 422
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
      projekt_manager_assignments_attributes: [:id, :projekt_manager_id, :projekt_id, permissions: []]
    ]
    params.require(:projekt).permit(attributes, translation_params(Projekt))
  end

  def projekt_page_params
    params.require(:page).permit(
      :title, :subtitle
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
    @projekt = Projekt
      .includes(
        :projekt_phases,
        :content_blocks,
        projekt_phases: [
          :settings,
          :individual_group_values,
          :geozone_restrictions
        ]
      )
      .find(params[:id])
  end

  def setting_params
    params.require(:setting).permit(:key, :value)
  end

  def content_block_body_params
    params.require(:projekt).permit(:body)
  end

  def create_default_content_block(projekt)
    # Create a blank content block for projects created through the API
    projekt.content_blocks.create!(
      name: "custom",
      locale: "de",
      body: "",
      key: "projekt_content_block_#{projekt.id}_1_#{Time.now.to_i}",
      position: 1
    )
  end
end
