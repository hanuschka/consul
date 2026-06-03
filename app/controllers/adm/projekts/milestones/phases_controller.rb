class Adm::Projekts::Milestones::PhasesController < Adm::Projekts::Milestones::BaseController
  private

    def set_milestoneable
      @milestoneable = @projekt_phase
    end

    def after_create(milestone)
      NotificationServices::NewProjektMilestoneNotifier.call(milestone.id)
    end

    def milestones_index_url
      milestones_adm_projekts_phase_path(@projekt_phase)
    end

    def new_milestone_url
      new_adm_projekts_phase_milestone_path(@projekt_phase)
    end

    def edit_milestone_url(milestone)
      edit_adm_projekts_phase_milestone_path(@projekt_phase, milestone)
    end

    def delete_milestone_url(milestone)
      adm_projekts_phase_milestone_path(@projekt_phase, milestone)
    end

    def milestone_update_url(milestone)
      adm_projekts_phase_milestone_path(@projekt_phase, milestone)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.milestones.title"), url: milestones_index_url },
        { name: action_title }
      ]
    end
end
