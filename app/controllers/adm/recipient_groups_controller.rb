module Adm
  class RecipientGroupsController < Adm::BaseController
    def index
      authorize [:adm, :recipient_group]
      @pagy, @recipient_groups = pagy(
        policy_scope([:adm, RecipientGroup]).order(created_at: :desc)
      )

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.index.tabs.recipient_groups") }
      ]
    end

    def new
      @recipient_group = RecipientGroup.new
      authorize [:adm, @recipient_group]

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.index.tabs.recipient_groups"), url: adm_recipient_groups_path },
        { name: t(".title") }
      ]
    end

    def create
      @recipient_group = RecipientGroup.new(recipient_group_params)
      authorize [:adm, @recipient_group]

      if @recipient_group.save
        redirect_to adm_recipient_groups_path, notice: t(".success")
      else
        @breadcrumbs = [
          { name: t("adm.menu.items.notifications"), icon: "send" },
          { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.index.tabs.recipient_groups"), url: adm_recipient_groups_path },
          { name: t("adm.recipient_groups.new.title") }
        ]
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @recipient_group = RecipientGroup.find(params[:id])
      authorize [:adm, @recipient_group]

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.index.tabs.recipient_groups"), url: adm_recipient_groups_path },
        { name: t(".title") }
      ]
    end

    def update
      @recipient_group = RecipientGroup.find(params[:id])
      authorize [:adm, @recipient_group]

      if @recipient_group.update(recipient_group_params)
        redirect_to adm_recipient_groups_path, notice: t(".success")
      else
        @breadcrumbs = [
          { name: t("adm.menu.items.notifications"), icon: "send" },
          { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.index.tabs.recipient_groups"), url: adm_recipient_groups_path },
          { name: t("adm.recipient_groups.edit.title") }
        ]
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @recipient_group = RecipientGroup.find(params[:id])
      authorize [:adm, @recipient_group]

      @recipient_group.destroy!
      redirect_to adm_recipient_groups_path, notice: t(".success")
    end

    def select_options
      authorize [:adm, :recipient_group]
      set_available_options_for_kind
      set_available_access_methods if @available_options_for_kind.blank?

      respond_to do |format|
        format.turbo_stream
      end
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

          elsif params[:kind]&.start_with?("Projekt_")
            @label_key = "label_for_projekt_phase"
            p_id = params[:kind].split("_").last
            ProjektPhase.where(projekt_id: p_id, type: "ProjektPhase::BudgetPhase")
              .map { |pp| [pp.title, "#{pp.type}_#{pp.id}"] }
              .unshift([t("adm.recipient_groups.new.select_options.projekt_related"), "projekt_related_#{p_id}"])
          end
      end

      def set_available_access_methods
        if params[:kind]&.start_with?("ProjektPhase::")
          projekt_phase = ProjektPhase.find(params[:kind].split("_").last)
          @available_access_methods = access_methods_for_projekt_phase(projekt_phase)
          @origin_class_name = params[:kind].split("_").first
          @origin_class_object_id = params[:kind].split("_").last
        elsif params[:kind] == "user_roles"
          @available_access_methods = [["newsletter_subscriber_ids"], ["all_newsletter_subscriber_ids"], ["administrators_ids"]]
          @origin_class_name = "User"
        elsif params[:kind]&.start_with?("projekt_related")
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
end
