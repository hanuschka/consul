class Adm::Ideas::IdeasController < Adm::Ideas::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes

  def index
    base_scope = policy_scope(Idea, policy_scope_class: Adm::Ideas::IdeaPolicy::Scope)
    base_scope = filter_assigned_ideas_only(base_scope)
    @pagy, @ideas = pagy(Adm::IdeasQuery.call(base_scope, params))

    @title_header_options = { search: true }
    @created_at_header_options = { sort: true }
    @category_header_options = { filter_options: category_filter_options }
    @officer_header_options = { filter_options: officer_filter_options }

    @breadcrumbs = [{ name: t("adm.ideas.menu.items.ideas") }]
  end

  def show
    @idea = Idea.find(params[:id])
    authorize @idea, policy_class: Adm::Ideas::IdeaPolicy

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path },
          { name: @idea.title }
        ]

        @image_url = @idea.image&.attachment&.variant(
          resize_to_limit: [500, 500],
          format: "jpeg"
        )
      end
      format.pdf do
        pdf_content = PdfServices::IdeaExporter.call(@idea, request.host)
        send_data pdf_content.render, filename: "idea_#{params[:id]}.pdf", type: "application/pdf"
      end
    end
  end

  def edit
    @idea = Idea.find(params[:id])
    authorize @idea, policy_class: Adm::Ideas::IdeaPolicy

    @idea.build_image(user: current_user) unless @idea.image
    @idea.create_map_location unless @idea.map_location

    @breadcrumbs = [
      { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path },
      { name: @idea.title }
    ]
  end

  def update
    @idea = Idea.find(params[:id])
    authorize @idea, policy_class: Adm::Ideas::IdeaPolicy

    if @idea.update(idea_params)
      notify_new_officer(@idea)

      if turbo_frame_request?
        flash.now[:success] = t("adm.attribute.update.success")
        render turbo_stream: turbo_stream.replace(
          turbo_frame_request_id,
          partial: "adm/ideas/ideas/#{frame_partial_path}",
          locals: { idea: @idea }
        )
      else
        redirect_to edit_adm_ideas_idea_path(@idea), notice: t("adm.attribute.update.success")
      end
    else
      render :edit
    end
  end

  def destroy
    @idea = Idea.find(params[:id])
    authorize @idea, policy_class: Adm::Ideas::IdeaPolicy

    @idea.destroy!
  end

  def administer
    @idea = Idea.find(params[:id])
    authorize @idea, :update?, policy_class: Adm::Ideas::IdeaPolicy

    @breadcrumbs = [
      { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path },
      { name: @idea.title }
    ]
  end

  def audits
    @idea = Idea.find(params[:id])
    authorize @idea, :show?, policy_class: Adm::Ideas::IdeaPolicy
  end

  def toggle_accepted
    @idea = Idea.find(params[:id])
    authorize @idea, :update?, policy_class: Adm::Ideas::IdeaPolicy

    accepted = ActiveModel::Type::Boolean.new.cast(params[:idea][:accepted])
    @idea.update!(admin_accepted_at: accepted ? Time.zone.now : nil)
  end

  def toggle_image
    @idea = Idea.find(params[:id])
    authorize @idea, :update?, policy_class: Adm::Ideas::IdeaPolicy

    @idea.image.toggle!(:concealed)
    redirect_to edit_adm_ideas_idea_path(@idea)
  end

  def update_official_answer
    @idea = Idea.find(params[:id])
    authorize @idea, :update?, policy_class: Adm::Ideas::IdeaPolicy

    if @idea.update(params.require(:idea).permit(translation_params(Idea)))
      flash.now[:success] = t(".success")
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@idea, :official_answer),
      Adm::AttributeEditorComponent.new(
        @idea,
        :official_answer,
        :rich_text,
        path: update_official_answer_adm_ideas_idea_path(@idea),
        label: t("adm.ideas.ideas.show.official_answer"),
        description: t("adm.ideas.ideas.show.official_answer_hint")
      )
    )
  end

  private

    def idea_params
      attributes = [:video_url, :on_behalf_of,
                    :votes_needed_for_success, :timeframe,
                    :idea_category_id, :idea_officer_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:idea).permit(attributes, translation_params(Idea))
    end

    def filter_assigned_ideas_only(scope)
      return scope if current_user.administrator? || current_user.idea_manager?
      return scope unless Setting["ideas.admins_must_assign_officer"].present?
      raise Pundit::NotAuthorizedError unless current_user.idea_officer?

      scope.where(officer: current_user.idea_officer)
    end

    def category_filter_options
      Idea::Category.all.map { |c| [c.id, c.name] }
    end

    def officer_filter_options
      Idea::Officer.all.map { |o| [o.id, o.name] }
    end

    def notify_new_officer(idea)
      return if idea.idea_officer_id_before_last_save == idea.idea_officer_id

      IdeaMailer.notify_officer(idea, idea.officer).deliver_later
    end

end
