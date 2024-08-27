class MovePollSettingsToProjektPhase < ActiveRecord::Migration[6.1]
  def up
    return unless table_exists?(:polls) && table_exists?(:projekt_phases)

    ActiveRecord::Base.transaction do
      ProjektPhase::VotingPhase.includes(:polls).find_each do |voting_phase|
        next if voting_phase.polls.empty?

        show_on_home_page = voting_phase.polls.last&.show_on_home_page ? "active" : ""
        voting_phase.settings.find_or_create_by!(key: "resource.show_on_home_page").update!(value: show_on_home_page)

        show_on_index_page = voting_phase.polls.last&.show_on_index_page ? "active" : ""
        voting_phase.settings.find_or_create_by!(key: "resource.show_on_index_page").update!(value: show_on_index_page)

        wizard_mode = voting_phase.polls.last&.wizard_mode ? "active" : ""
        voting_phase.settings.find_or_create_by!(key: "resource.wizard_mode").update!(value: wizard_mode)

        results_enabled = voting_phase.polls.joins(:report).last&.report&.results ? "active" : ""
        voting_phase.settings.find_or_create_by!(key: "resource.results_enabled").update!(value: results_enabled)

        stats_enabled = voting_phase.polls.joins(:report).last&.report&.stats ? "active" : ""
        voting_phase.settings.find_or_create_by!(key: "resource.stats_enabled").update!(value: stats_enabled)

        advanced_stats_enabled = voting_phase.polls.joins(:report).last&.report&.advanced_stats ? "active" : ""
        voting_phase.settings.find_or_create_by!(key: "resource.advanced_stats_enabled").update!(value: advanced_stats_enabled)
      end
    end
  end

  def down
  end
end
