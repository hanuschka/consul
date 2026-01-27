module Adm
  class ProjektLabelsController < Adm::BaseController
    before_action :set_projekt_phase
    before_action :set_projekt_label, only: %i[edit update destroy]

    def new
      @projekt_label = @projekt_phase.projekt_labels.new
      authorize [:adm, @projekt_label]

      @breadcrumbs = breadcrumbs_for_action(t(".title"))
    end

    def create
      @projekt_label = @projekt_phase.projekt_labels.new(projekt_label_params)
      authorize [:adm, @projekt_label]

      if @projekt_label.save
        redirect_to projekt_labels_adm_projekt_phase_path(@projekt_phase), notice: t(".success")
      else
        @breadcrumbs = breadcrumbs_for_action(t("adm.projekt_labels.new.title"))
        render :new
      end
    end

    def edit
      authorize [:adm, @projekt_label]

      @breadcrumbs = breadcrumbs_for_action(t(".title"))
    end

    def update
      authorize [:adm, @projekt_label]

      if @projekt_label.update(projekt_label_params)
        redirect_to projekt_labels_adm_projekt_phase_path(@projekt_phase), notice: t(".success")
      else
        @breadcrumbs = breadcrumbs_for_action(t("adm.projekt_labels.edit.title"))
        render :edit
      end
    end

    def destroy
      authorize [:adm, @projekt_label]

      @projekt_label.destroy!
      redirect_to projekt_labels_adm_projekt_phase_path(@projekt_phase), notice: t(".success")
    end

    private

      def set_projekt_phase
        @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
      end

      def set_projekt_label
        @projekt_label = ProjektLabel.find(params[:id])
      end

      def projekt_label_params
        params.require(:projekt_label).permit(:name, :icon)
      end

      def breadcrumbs_for_action(action_title)
        [
          { name: t("adm.menu.items.home"), url: adm_root_path },
          { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
          { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t("adm.projekt_phases.projekt_labels.title"), url: projekt_labels_adm_projekt_phase_path(@projekt_phase) },
          { name: action_title }
        ]
      end
  end
end
