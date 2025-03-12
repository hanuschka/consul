class Admin::RecipientGroupsController < Admin::BaseController
  load_and_authorize_resource only: [:edit, :update, :destroy]

  def index
    @recipient_groups = RecipientGroup.order(created_at: :desc).page(params[:page])
  end

  def new
    @recipient_group = RecipientGroup.new
  end

  def create
    @recipient_group = RecipientGroup.new(recipient_group_params)
    if @recipient_group.save
      redirect_to admin_recipient_groups_path, notice: t("custom.admin.recipient_groups.create.notice")
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @recipient_group.update(recipient_group_params)
      redirect_to admin_recipient_groups_path, notice: t("custom.admin.recipient_groups.update.notice")
    else
      render :edit
    end
  end

  def destroy
    @recipient_group.destroy!
    redirect_to admin_recipient_groups_path, notice: t("custom.admin.recipient_groups.destroy.notice")
  end

  def select_options
    set_available_options_for_kind
    set_available_access_methods if @available_options_for_kind.blank?
  end

  private

    def recipient_group_params
      params.require(:recipient_group).permit(
        :name, :access_method,
        :origin_class_name, :origin_class_object_id
      )
    end

    def set_available_options_for_kind
      @available_options_for_kind =
        if params[:kind] == "projekts"
          @label_key = "label_for_projekt"
          Projekt.all.map { |p| [p.name, "Projekt_#{p.id}"] }

        elsif params[:kind].start_with?("Projekt_")
          @label_key = "label_for_projekt_phase"
          p_id = params[:kind].split("_").last
          ProjektPhase.where(projekt_id: p_id, type: "ProjektPhase::BudgetPhase")
            .map { |pp| [pp.title, "#{pp.type}_#{pp.id}"] }
            .unshift([t("custom.admin.recipient_groups.new.select_options.projekt_related"), "projekt_related_#{p_id}"])
        end
    end

    def set_available_access_methods
      if params[:kind].start_with?("ProjektPhase::")
        projekt_phase = ProjektPhase.find(params[:kind].split("_").last)
        @available_access_methods = access_methods_for_projekt_phase(projekt_phase)
        @origin_class_name = params[:kind].split("_").first
        @origin_class_object_id = params[:kind].split("_").last
      elsif params[:kind] == "user_roles"
        @available_access_methods = [["all_user_ids"], ["administrators_ids"]]
        @origin_class_name = "User"
      elsif params[:kind].start_with?("projekt_related")
        @available_access_methods = [["any_phase_subscribers_ids"]]
        @origin_class_name = "Projekt"
        @origin_class_object_id = params[:kind].split("_").last
      end
    end

    def access_methods_for_projekt_phase(projekt_phase)
      case projekt_phase.type
      when "ProjektPhase::BudgetPhase"
        [
          ["authors_of_feasible_ids"],
          ["authors_of_unfeasible_ids"],
          ["authors_of_selected_ids"],
          ["authors_of_not_winners_ids"],
          ["authors_of_winners_ids"]
        ]
      end
    end
end
