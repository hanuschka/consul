module Adm
  class ProjektsController < Adm::BaseController
    before_action :find_projekt, only: [:show, :edit, :update, :destroy, :toggle_activated]

    def index
      authorize [:adm, Projekt]
      @pagy, @projekts = pagy(policy_scope([:adm, Projekt]), limit: 10)
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts") }
      ]
    end

    def show
      authorize [:adm, @projekt]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt.name }
      ]
    end

    def edit
      authorize [:adm, @projekt]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt.name, url: adm_projekt_path(@projekt) },
        { name: t("adm.projekts.edit.title") }
      ]
    end

    def update
      authorize [:adm, @projekt]

      if @projekt.update(projekt_params)
        redirect_to adm_projekt_path(@projekt), notice: t("adm.projekts.update.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [:adm, @projekt]

      @projekt.children.each { |child| child.update(parent: nil) }
      @projekt.debates.unscope(where: :hidden_at).each { |debate| debate.update(projekt_id: nil) }
      @projekt.proposals.unscope(where: :hidden_at).each { |proposal| proposal.update(projekt_id: nil) }
      @projekt.polls.unscope(where: :hidden_at).each { |poll| poll.update(projekt_id: nil) }
      @projekt.destroy!

      redirect_to adm_projekts_path, notice: t("adm.projekts.destroy.success")
    end

    def toggle_activated
      authorize [:adm, @projekt], :update?

      setting = @projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")
      new_value = ActiveModel::Type::Boolean.new.cast(params[:projekt][:activated]) ? "active" : ""
      setting.update!(value: new_value)
    end

    private

      def find_projekt
        @projekt = Projekt.find(params[:id])
      end

      def projekt_params
        params.require(:projekt).permit(
          :name, :total_duration_start, :total_duration_end,
          :show_start_date_in_frontend, :show_end_date_in_frontend
        )
      end
  end
end
