module CommentableActions
  extend ActiveSupport::Concern
  include Polymorphic
  include Search
  include RemotelyTranslatable

  def index
    @resources = resource_model.all

    @resources = @current_order == "recommendations" && current_user.present? ? @resources.recommendations(current_user) : @resources.for_render
    @resources = @resources.search(@search_terms) if @search_terms.present?
    @resources = @advanced_search_terms.present? ? @resources.filter(@advanced_search_terms) : @resources
    @resources = @resources.tagged_with(@tag_filter) if @tag_filter

    @resources = @resources.page(params[:page]).send("sort_by_#{@current_order}")

    index_customization

    @tag_cloud = tag_cloud
    @banners = Banner.in_section(section(resource_model.name)).with_active

    set_resource_votes(@resources)

    set_resources_instance
    @remote_translations = detect_remote_translations(@resources, featured_proposals)
  end

  def update
    if resource.update(strong_params)
        redirect_path = url_for(controller: controller_name, action: :show, id: @resource.id)
        redirect_to redirect_path, notice: t("flash.actions.create.#{resource_name.underscore}")
    else
        load_categories
        load_geozones
        set_resource_instance
        render :edit
    end
  end

  private

    def parse_tag_filter
      if params[:tag].present?
        @tag_filter = params[:tag] if Tag.named(params[:tag]).exists?
      end
    end

end