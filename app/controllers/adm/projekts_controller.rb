module Adm
  class ProjektsController < Adm::BaseController
    before_action :find_projekt, only: [:details, :edit, :update, :destroy, :toggle_activated]

    def index
      authorize [:adm, Projekt]
      base_scope = ProjektsQuery.call(policy_scope([:adm, Projekt]), params)
      @pagy, @projekts = pagy(base_scope, limit: 10)

      @name_header_options = { sort: true, search: true }
      @start_date_header_options = { sort: true }
      @end_date_header_options = { sort: true }

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts") }
      ]
    end

    def details
      authorize [:adm, @projekt], :show?
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
        { name: @projekt.name, url: details_adm_projekt_path(@projekt) },
        { name: t("adm.projekts.edit.title") }
      ]
    end

    def update
      authorize [:adm, @projekt]

      if @projekt.update(projekt_params)
        flash.now[:success] = t("adm.attribute.update.success")
      end

      render turbo_stream: turbo_stream.replace(
        turbo_frame_request_id,
        partial: "adm/projekts/#{frame_partial_path}",
        locals: { projekt: @projekt }
      )
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

      def frame_partial_path
        turbo_frame_request_id&.gsub("__", "/")
      end

      def projekt_params
        params.require(:projekt).permit(
          :name, :total_duration_start, :total_duration_end,
          :show_start_date_in_frontend, :show_end_date_in_frontend,
          :geozone_affiliated,
          landing_page_ids: [],
          geozone_affiliation_ids: []
        )
      end
  end
end
