class Pages::Projekts::FooterPhasesComponent < ApplicationComponent
  attr_reader :projekt, :default_projekt_phase

  def initialize(projekt, default_projekt_phase, namespace: nil)
    @projekt = projekt
    @default_projekt_phase = default_projekt_phase
    @namespace = namespace
  end

  private

    def show_arrows?
      projekt_phases.size >= 4
    end

    def phase_name(phase)
      t("custom.projekts.phase_name.#{phase.name}")
    end

    def projekt_phases
      phases = projekt.projekt_phases.includes(:translations, :age_restriction)

      if helpers.show_admin_controls_for_projekt?(projekt)
        phases
      else
        phases.active.frontend_visible
      end
    end
end
