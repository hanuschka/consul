class InternalApi::ProjektsController < InternalApi::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :process_tags, only: [:update]
  before_action :find_projekt, only: [
    :update, :update_page, :update_title_image, :import, :export
  ]

  skip_authorization_check

  OVERVIEW_DEFAULT_PER_PAGE = 100
  OVERVIEW_MAX_PER_PAGE = 500
  OVERVIEW_PRELOADS = [
    :map_location,
    :projekt_settings,
    :hard_individual_group_values,
    :tags,
    :sdg_goals,
    :translations,
    :projekt_phases,
    { page: [:image, :translations] },
    { active_and_visible_projekt_phases: :translations },
    { sdg_relations: :related_sdg }
  ].freeze

  def overview
    stamp_currently_visible_projekts

    projekts_on_dt_global_overview =
      Projekt
        .where(on_dt_global_overview: true)
        .order(:id)

    if params[:page].present?
      render json: paginated_overview_payload(projekts_on_dt_global_overview)
    else
      render json: { projekts: serialize_for_overview(projekts_on_dt_global_overview) }
    end
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

  # Publishing a projekt to the global overview is what makes it reusable by
  # another instance, so it is also what gates the export.
  def export
    if !@projekt.on_dt_global_overview?
      render json: { error: "Projekt is not available for reuse" }, status: :not_found

      return
    end

    render json: { export: Projekts::SerializeForExport.call(source: @projekt) }
  end

  private

  def stamp_currently_visible_projekts
    Projekt
      .activated
      .with_published_custom_page
      .show_in_overview_page
      .regular
      .where(on_dt_global_overview: false)
      .update_all(on_dt_global_overview: true)
  end

  def paginated_overview_payload(projekts)
    per_page = overview_per_page
    page = [params[:page].to_i, 1].max
    total_count = projekts.count
    page_of_projekts = projekts.offset((page - 1) * per_page).limit(per_page)

    {
      projekts: serialize_for_overview(page_of_projekts),
      pagination: {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def overview_per_page
    requested_per_page = params[:per_page].to_i
    return OVERVIEW_DEFAULT_PER_PAGE if requested_per_page <= 0

    [requested_per_page, OVERVIEW_MAX_PER_PAGE].min
  end

  def serialize_for_overview(projekts)
    projekts.includes(OVERVIEW_PRELOADS).map do |projekt|
      Projekts::SerializeForOverview.call(projekt)
    end
  end

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
