module Adm
  class IndividualGroupsController < Adm::BaseController
    def index
      authorize [:adm, :individual_group]
      @pagy, @individual_groups = pagy(policy_scope([:adm, IndividualGroup]).order(:id))

      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.individual_groups") }
      ]
    end

    def new
      @individual_group = IndividualGroup.new
      authorize [:adm, @individual_group]

      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.individual_groups"), url: adm_individual_groups_path },
        { name: t(".title") }
      ]
    end

    def create
      @individual_group = IndividualGroup.new(individual_group_params)
      authorize [:adm, @individual_group]

      if @individual_group.save
        redirect_to adm_individual_groups_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @individual_group = IndividualGroup.find(params[:id])
      authorize [:adm, @individual_group]

      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.individual_groups"), url: adm_individual_groups_path },
        { name: t(".title") }
      ]
    end

    def update
      @individual_group = IndividualGroup.find(params[:id])
      authorize [:adm, @individual_group]

      if @individual_group.update(individual_group_params)
        redirect_to adm_individual_groups_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @individual_group = IndividualGroup.find(params[:id])
      authorize [:adm, @individual_group]

      @individual_group.destroy!
      redirect_to adm_individual_groups_path, notice: t(".success")
    end

    private

      def individual_group_params
        params.require(:individual_group).permit(:name, :kind, :visible)
      end
  end
end
