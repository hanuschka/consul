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

    def create
      @recipient_group = RecipientGroup.new(recipient_group_params)
      @recipient_group.name = t("adm.recipient_groups.create.default_name") if @recipient_group.name.blank?
      authorize [:adm, @recipient_group]

      @recipient_group.save!
      redirect_to edit_adm_recipient_group_path(@recipient_group), notice: t(".success")
    end

    def edit
      @recipient_group = RecipientGroup.find(params[:id])
      authorize [:adm, @recipient_group]

      @counts = RecipientGroupResolver.new(@recipient_group).per_filter_counts
      # Defensive pad in case resolver returns fewer entries than filters
      while @counts.size < @recipient_group.filters.size
        @counts << { count: 0, delta: 0 }
      end

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

      attrs = recipient_group_params
      attrs[:name] = t("adm.recipient_groups.create.default_name") if attrs.key?(:name) && attrs[:name].blank?

      if @recipient_group.update(attrs)
        respond_to do |format|
          format.html { redirect_to adm_recipient_groups_path, notice: t(".success") }
          format.json { head :ok }
        end
      else
        respond_to do |format|
          format.html do
            @breadcrumbs = [
              { name: t("adm.menu.items.notifications"), icon: "send" },
              { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
              { name: t("adm.newsletters.index.tabs.recipient_groups"), url: adm_recipient_groups_path },
              { name: t("adm.recipient_groups.edit.title") }
            ]
            render :edit, status: :unprocessable_entity
          end
          format.json do
            render json: { errors: @recipient_group.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end
    end

    def destroy
      @recipient_group = RecipientGroup.find(params[:id])
      authorize [:adm, @recipient_group]

      @recipient_group.destroy!
      redirect_to adm_recipient_groups_path, notice: t(".success")
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
      # `dependent: :restrict_with_exception` on `has_many :newsletters` only sees
      # non-hidden records (Newsletter uses `acts_as_paranoid column: :hidden_at`),
      # so when every related newsletter is soft-deleted the association reports
      # "no children" and Postgres' FK constraint raises `InvalidForeignKey`
      # instead of Rails' `DeleteRestrictionError`. Treat both as the same UX.
      redirect_to adm_recipient_groups_path, alert: t(".restricted")
    end

    private

      def recipient_group_params
        params.fetch(:recipient_group, {}).permit(:name)
      end
  end
end
