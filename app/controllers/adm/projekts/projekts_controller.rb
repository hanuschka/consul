class Adm::Projekts::ProjektsController < Adm::Projekts::BaseController
  before_action :find_projekt, only: [:details, :visibility, :projekt_managers, :map, :phases, :update, :destroy, :toggle_activated, :update_default_phase, :notify_reviewers, :toggle_hide_content_background, :convert_to_new_content_block_mode, :update_color, :update_image, :delete_image]

  def new
    authorize [:adm, :projekts, Projekt], :create?

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: t(".title") }
    ]
  end

  def create
    authorize [:adm, :projekts, Projekt], :create?
    @projekt = Projekt.new(create_params.merge(author: current_user))

    if @projekt.save
      redirect_to details_adm_projekts_projekt_path(@projekt), notice: t(".success")
    else
      redirect_to new_adm_projekts_projekt_path, alert: @projekt.errors.full_messages.join(", ")
    end
  end

  def details
    authorize [:adm, :projekts, @projekt], :show?
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page.title, id: "breadcrumb-projekt-name" },
      { name: t(".title") }
    ]
  end

  def visibility
    authorize [:adm, :projekts, @projekt], :show?
    @individual_groups = IndividualGroup.hard.visible
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page.title, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def projekt_managers
    authorize [:adm, :projekts, @projekt], :show?

    # Auto-create assignments for all projekt managers
    ProjektManager.find_each do |pm|
      pm.projekt_manager_assignments.find_or_create_by!(projekt: @projekt)
    end
    @projekt_manager_assignments = @projekt.projekt_manager_assignments.includes(projekt_manager: :user)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page.title, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def map
    authorize [:adm, :projekts, @projekt], :show?
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page.title, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def phases
    authorize [:adm, :projekts, @projekt], :show?
    base_scope = policy_scope([:adm, :projekts, @projekt.projekt_phases])
      .includes(:geozone_restrictions, :age_restriction)
    @projekt_phases = ProjektPhasesQuery.call(base_scope, params)

    @name_header_options = { search: true }

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page.title, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def update
    authorize [:adm, :projekts, @projekt]

    if @projekt.update(projekt_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    render turbo_stream: turbo_stream.replace(
      turbo_frame_request_id,
      partial: "adm/projekts/projekts/#{frame_partial_path}",
      locals: { projekt: @projekt }
    )
  end

  def destroy
    authorize [:adm, :projekts, @projekt]

    @projekt.children.each { |child| child.update(parent: nil) }
    @projekt.debates.unscope(where: :hidden_at).each { |debate| debate.update(projekt_id: nil) }
    @projekt.proposals.unscope(where: :hidden_at).each { |proposal| proposal.update(projekt_id: nil) }
    @projekt.polls.unscope(where: :hidden_at).each { |poll| poll.update(projekt_id: nil) }
    @projekt.destroy!

    redirect_to adm_projekts_root_path, notice: t("adm.projekts.projekts.destroy.success")
  end

  def notify_reviewers
    authorize [:adm, :projekts, @projekt], :update?

    NotificationServices::NewProjektNotifier.call(@projekt)

    respond_to do |format|
      format.html { redirect_to page_path(@projekt.page.slug), notice: t(".success") }
      format.json { render json: { success: true, message: t(".success") } }
    end
  end

  def toggle_hide_content_background
    authorize [:adm, :projekts, @projekt], :update?

    @projekt.update!(show_content_background: !@projekt.show_content_background)

    render json: { show_content_background: @projekt.show_content_background }
  end

  def update_color
    authorize [:adm, :projekts, @projekt], :update?

    if @projekt.update(color: params[:color].presence)
      render json: { ok: true, color: @projekt.color }
    else
      render json: { ok: false, errors: @projekt.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def convert_to_new_content_block_mode
    authorize [:adm, :projekts, @projekt], :update?

    result = Projekts::ConvertToNewContentBlockMode.call(projekt: @projekt)

    if result.success?
      flash[:notice] = t("custom.projekts.page.convert_to_content_blocks.success")
    else
      flash[:error] = t("custom.projekts.page.convert_to_content_blocks.error")
    end

    redirect_to page_path(@projekt.page.slug)
  end

  def toggle_activated
    authorize [:adm, :projekts, @projekt], :update?

    setting = @projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")
    new_value = ActiveModel::Type::Boolean.new.cast(params[:projekt][:activated]) ? "active" : ""
    setting.update!(value: new_value)
  end

  def update_default_phase
    authorize [:adm, :projekts, @projekt], :update?

    @projekt_phase = @projekt.projekt_phases.find(params[:projekt_phase_id])
    param_key = @projekt_phase.model_name.param_key
    @projekt_phase.default_phase = params[param_key][:default_phase]
    @projekt_phases = @projekt.projekt_phases
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_image
    authorize [:adm, :projekts, @projekt], :update?

    page = @projekt.page
    image = page.image || ::Image.new(imageable: page)
    image.attachment = params.require(:file)
    image.user = current_user

    if image.save
      page.association(:image).reset

      render json: { ok: true, message: t(".success") }
    else
      render json: { ok: false, errors: image.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def delete_image
    authorize [:adm, :projekts, @projekt], :update?

    @projekt.page.image&.destroy
    @projekt.page.association(:image).reset

    render json: { ok: true, message: t(".success") }
  end

  private

    def find_projekt
      @projekt = Projekt.find(params[:id])
    end

    def projekt_params
      params.require(:projekt).permit(
        :name, :total_duration_start, :total_duration_end,
        :show_start_date_in_frontend, :show_end_date_in_frontend,
        :geozone_affiliated,
        :landing_page_id,
        geozone_affiliation_ids: [],
        registered_address_district_affiliation_ids: [],
        individual_group_value_ids: []
      )
    end

    def create_params
      params.require(:projekt).permit(:name)
    end
end
