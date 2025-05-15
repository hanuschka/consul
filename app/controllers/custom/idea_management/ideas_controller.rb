class IdeaManagement::IdeasController < IdeaManagement::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes
  include CustomSearch

  load_and_authorize_resource

  def index
    filter_assigned_reports_only
    @ideas = apply_filters(@ideas)

    if params[:responsible].present?
      klass, id = params[:responsible].split("_")
      @ideas = @ideas.where(responsible_type: klass, responsible_id: id)
    end

    @ideas = @ideas.order(id: :desc)

    unless params[:format] == "csv"
      @ideas = @ideas.page(params[:page].presence || 0).per(params[:limit].presence || 20)
    end

    respond_to do |format|
      format.html
      format.csv do
        send_data CsvServices::IdeasExporter.call(@ideas),
          filename: "ideas-#{Time.zone.today}.csv"
      end
    end
  end

  def show
    @idea = Idea.find(params[:id])
    @official_answer_templates = Idea::OfficialAnswerTemplate.all

    set_current_responsible

    respond_to do |format|
      format.html
      format.pdf do
        pdf_content = PdfServices::IdeaExporter.call(@idea, request.host)
        send_data pdf_content.render, filename: "idea_#{params[:id]}.pdf", type: "application/pdf"
      end
    end
  end

  def edit
    @idea = Idea.find(params[:id])
    @districts = RegisteredAddress::District.joins(:map_location).order(created_at: :asc)
    @map_coordinates_for_districts = @districts.map do |district|
      [district.id, [district.map_location.latitude, district.map_location.longitude]]
    end.to_h
  end

  def update
    @idea = Idea.find(params[:id])

    update_responsible

    if @idea.update(idea_params)
      notify_new_officer(@idea)
      notify_author_about_status_change(@idea)
      update_status_change_date(@idea)

      redirect_to idea_management_ideas_path, notice: t("custom.admin.ideas.update.success_notice")
    else
      render :edit
    end
  end

  def destroy
    @idea = Idea.find(params[:id])
    @idea.destroy!
  end

  def audits
  end

  def accept
    enabled = ["1", "true"].include?(params[:idea][:admin_accepted])
    idea = Idea.find(params[:idea][:id])

    idea.update!(admin_accepted: enabled)

    head :ok
  end

  def toggle_image
    @idea.image.toggle!(:concealed)
    redirect_to polymorphic_path([@namespace, @idea], action: :edit)
  end

  private

    def idea_params
      attributes = [:video_url, :on_behalf_of,
                    :idea_category_id,
                    :idea_status_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:idea).permit(attributes, translation_params(Idea))
    end

    def filter_assigned_reports_only
      return if current_user.administrator? || current_user.idea_manager?
      return unless Setting["ideas.admins_must_assign_officer"].present?
      raise CanCan::AccessDenied unless current_user.idea_officer?

      idea_ids = @ideas.select do |dr|
        dr.responsible.is_a?(Idea::Officer) && dr.responsible == current_user.idea_officer ||
          dr.responsible.is_a?(Idea::OfficerGroup) && dr.responsible.officers.include?(current_user.idea_officer)
      end

      @ideas = @ideas.where(id: idea_ids)
    end

    def notify_new_officer(dr)
      return if dr.responsible_id_before_last_save == dr.responsible_id && dr.responsible_type_before_last_save == dr.responsible_type

      if dr.responsible.is_a?(Idea::Officer)
        IdeaMailer.notify_officer(dr, dr.responsible).deliver_later
      elsif dr.responsible.is_a?(Idea::OfficerGroup)
        if dr.responsible.default_email.present?
          IdeaMailer.notify_default_officer_group_email(dr).deliver_later
        end

        dr.responsible.officers.each do |officer|
          IdeaMailer.notify_officer(dr, officer).deliver_later
        end
      end
    end

    def notify_author_about_status_change(dr)
      return if dr.idea_status_id_before_last_save == dr.idea_status_id

      IdeaMailer.notify_author_about_status_change(dr).deliver_later
    end

    def update_status_change_date(dr)
      return if dr.idea_status_id_before_last_save == dr.idea_status_id

      dr.update_column(:status_changed_at, Time.zone.now)
    end

    def set_current_responsible
      if @idea.responsible.is_a?(Idea::Officer)
        @idea.officer_id = @idea.responsible.id
      elsif @idea.responsible.is_a?(Idea::OfficerGroup)
        @idea.officer_group_id = @idea.responsible.id
      end
    end

    def update_responsible
      current_responsible = @idea.responsible

      if params[:idea]["officer_id"].present?
        @idea.responsible = Idea::Officer.find(params[:idea]["officer_id"])
      elsif params[:idea]["officer_group_id"].present?
        @idea.responsible = Idea::OfficerGroup.find(params[:idea]["officer_group_id"])
      end

      new_responsible = @idea.responsible
      @idea.assigned_at = Time.zone.now unless current_responsible == new_responsible
    end
end
