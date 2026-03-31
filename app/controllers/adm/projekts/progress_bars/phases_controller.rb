class Adm::Projekts::ProgressBars::PhasesController < Adm::Projekts::ProgressBars::BaseController
  private

    def set_progressable
      @progressable = @projekt_phase
    end

    def progress_bars_index_url
      progress_bars_adm_projekts_phase_path(@projekt_phase)
    end

    def progress_bar_update_url(progress_bar)
      adm_projekts_phase_progress_bar_path(@projekt_phase, progress_bar)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.progress_bars.title"), url: progress_bars_index_url },
        { name: action_title }
      ]
    end
end
