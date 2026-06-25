class InternalApi::ProjektsController < InternalApi::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :process_tags, only: [:update]
  before_action :find_projekt, only: [
    :update, :update_page, :update_title_image, :import
  ]

  skip_authorization_check

  def overview
    current_visible_projekts =
      Projekt
        .activated
        .with_published_custom_page
        .show_in_overview_page
        .regular

    current_visible_projekts
      .where(on_dt_global_overview: false)
      .update_all(on_dt_global_overview: true)

    projekts_on_dt_global_overview =
      Projekt
        .where(on_dt_global_overview: true)
        .includes(:page, :projekt_phases, :map_location)

    render json: {
      projekts: projekts_on_dt_global_overview.map do |projekt|
        Projekts::SerializeForOverview.call(projekt)
      end
    }
  end

  def create
    author = User.find(params[:author_user_id])
    @projekt = Projekt.new(projekt_params.merge(author: author))

    if @projekt.save
      update_page_attributes
      update_tags_and_sdgs

      render json: {
        id: @projekt.id,
        page_slug: @projekt.page&.slug,
        preview_code: @projekt.preview_code
      }, status: :created
    else
      render json: { errors: @projekt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @projekt.update(projekt_params)
      update_page_attributes
      update_tags_and_sdgs

      render json: { id: @projekt.id, message: "Projekt updated" }
    else
      render json: { errors: @projekt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_page
    page = @projekt.page

    if page.blank?
      render json: { error: "Page not found" }, status: :not_found

      return
    end

    if page.update(page_params)
      render json: { message: "Page updated" }
    else
      render json: { errors: page.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_title_image
    if params[:title_image].blank?
      render json: { error: "No image provided" }, status: :unprocessable_entity

      return
    end

    image = Image.new(
      attachment: params[:title_image],
      user: @projekt.author
    )

    @projekt.page.image = image

    if @projekt.page.save
      render json: { message: "Title image updated" }
    else
      render json: { error: "Failed to attach image" }, status: :unprocessable_entity
    end
  end

  def import
    if @projekt.update(projekt_params)
      update_page_attributes
      update_tags_and_sdgs

      render json: {
        id: @projekt.id,
        page_slug: @projekt.page&.slug,
        preview_code: @projekt.preview_code
      }
    else
      render json: { errors: @projekt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def find_projekt
    @projekt = Projekt.find(params[:id])
  end

  def projekt_params
    params.require(:projekt).permit(
      :name, :total_duration_start, :total_duration_end
    )
  end

  def page_params
    params.require(:site_customization_page).permit(
      :title, :subtitle, :status
    )
  end

  def update_page_attributes
    return if params[:projekt].blank?

    page = @projekt.page
    return if page.blank?

    page_updates = {}
    page_updates[:title] = params[:projekt][:title] if params[:projekt][:title].present?
    page_updates[:subtitle] = params[:projekt][:subtitle] if params[:projekt][:subtitle].present?

    page.update(page_updates) if page_updates.present?
  end

  def update_tags_and_sdgs
    return if params[:projekt].blank?

    if params[:projekt][:tag_list].present?
      @projekt.tag_list = params[:projekt][:tag_list]
      @projekt.save
    end

    if params[:projekt][:related_sdg_list].present?
      @projekt.related_sdg_list = params[:projekt][:related_sdg_list]
      @projekt.save
    end
  end
end
