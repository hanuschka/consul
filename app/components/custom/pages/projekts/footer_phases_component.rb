class Pages::Projekts::FooterPhasesComponent < ApplicationComponent
  attr_reader :projekt, :default_projekt_phase

  def initialize(projekt, default_projekt_phase)
    @projekt = projekt
    @default_projekt_phase = default_projekt_phase
  end

  private

    def show_arrows?
      # projekt.projekt_phases.to_a.select(&:phase_activated?).size >= 4
      max_size = helpers.embedded? ? 3 : 4
      projekt_phases.size >= max_size
    end

    def phase_name(phase)
      t("custom.projekts.phase_name.#{phase.name}")
    end

    def projekt_phases
      phases = projekt.projekt_phases.includes(:translations, :age_restriction)

      if embedded_and_frame_access_code_valid?(projekt)
        phases
      else
        phases.to_a.select(&:phase_activated?)
      end
    end
end
