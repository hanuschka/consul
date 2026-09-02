class Adm::Ideas::IdeasController < Adm::Ideas::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes

  def show
    @idea = Idea.find(params[:id])
    authorize @idea, policy_class: Adm::Ideas::IdeaPolicy

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path, icon: "lightbulb" },
          { name: @idea.title }
        ]

        @image_url = @idea.image&.attachment_variant(
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

    unless turbo_frame_request?
      redirect_to adm_ideas_idea_path(@idea)
      return
    end

    @idea.build_image(user: current_user) unless @idea.image
    @idea.create_map_location unless @idea.map_location

    @breadcrumbs = [
      { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path, icon: "lightbulb" },
      { name: @idea.title }
    ]
  end

  def update
    @idea = Idea.find(params[:id])
    authorize @idea, policy_class: Adm::Ideas::IdeaPolicy

    if @idea.update(idea_params)
      notify_new_officer(@idea)
      redirect_to adm_ideas_idea_path(@idea), notice: t("adm.attribute.update.success")
    else
      @idea.build_image(user: current_user) unless @idea.image
      @idea.create_map_location unless @idea.map_location
      @breadcrumbs = [
        { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path, icon: "lightbulb" },
        { name: @idea.title }
      ]
      render :edit, status: :unprocessable_entity
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
      { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path, icon: "lightbulb" },
      { name: @idea.title }
    ]
  end

  def audits
    @idea = Idea.find(params[:id])
    authorize @idea, :show?, policy_class: Adm::Ideas::IdeaPolicy

    @breadcrumbs = [
      { name: t("adm.ideas.menu.items.ideas"), url: adm_ideas_root_path, icon: "lightbulb" },
      { name: @idea.title }
    ]
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
    redirect_to adm_ideas_idea_path(@idea)
  end

  def update_official_answer
    @idea = Idea.find(params[:id])
    authorize @idea, :update?, policy_class: Adm::Ideas::IdeaPolicy

    if @idea.update(params.require(:idea).permit(:official_answer))
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
      attributes = [:title, :description, :video_url, :on_behalf_of,
                    :votes_needed_for_success, :timeframe,
                    :idea_category_id, :idea_officer_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:idea).permit(attributes)
    end

    def filter_assigned_ideas_only(scope)
      return scope if current_user.administrator? || current_user.idea_manager?
      return scope unless Setting["ideas.admins_must_assign_officer"].present?
      raise Pundit::NotAuthorizedError unless current_user.idea_officer?

      officer = current_user.idea_officer

      return scope if officer.manage_all?

      scope.where(officer: officer)
    end

    def notify_new_officer(idea)
      return if idea.idea_officer_id_before_last_save == idea.idea_officer_id

      IdeaMailer.notify_officer(idea, idea.officer).deliver_later
    end

end
