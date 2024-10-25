class InvertOnlyAdminsCreateProposals < ActiveRecord::Migration[6.1]
  def up
    ProjektPhase::ProposalPhase.reset_column_information

    ProjektPhase::ProposalPhase.find_each do |phase|
      old_setting = phase.settings.find_by(key: "feature.general.only_admins_create_proposals")
      phase.settings.find_or_create_by!(key: "feature.resource.users_can_create_proposals") do |setting|
        setting.value = old_setting.value == "" ? "active" : ""
      end
    end
  end

  def down
    ProjektPhase::ProposalPhase.find_each do |phase|
      new_setting = phase.settings.find_by(key: "feature.resource.users_can_create_proposals")
      phase.settings.find_or_create_by!(key: "feature.general.only_admins_create_proposals") do |setting|
        setting.value = new_setting.value == "" ? "active" : ""
      end
    end
  end
end
