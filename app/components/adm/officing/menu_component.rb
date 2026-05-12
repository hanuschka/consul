class Adm::Officing::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.officing.menu.aria_label")
  end

  def menu_items
    items = [
      { label: t("adm.officing.menu.items.home"), icon: "home", path: adm_officing_root_path }
    ]

    if current_user&.administrator?
      items << { label: t("adm.officing.menu.items.officing_managers"), icon: "badge", path: adm_officing_managers_path, active_prefix: "/adm/officing_managers" }
    end

    officing_manager = helpers.current_user.officing_manager

    if officing_manager
      (officing_manager.balloting_budgets + officing_manager.selecting_budgets).uniq.each do |budget|
        items << {
          label: budget.projekt.name,
          icon: "account_balance_wallet",
          path: verify_user_adm_officing_budget_path(budget)
        }
      end

      officing_manager.officing_proposal_phases.each do |proposal_phase|
        items << {
          label: proposal_phase.projekt.name,
          icon: "how_to_vote",
          path: verify_user_adm_officing_proposal_phase_path(proposal_phase)
        }
      end

      officing_manager.officing_voting_phases.each do |voting_phase|
        items << {
          label: voting_phase.projekt.name,
          icon: "ballot",
          path: verify_user_adm_officing_voting_phase_path(voting_phase)
        }
      end
    end

    if Adm::Officing::SettingPolicy.new(current_user, nil).show?
      items << { label: t("adm.officing.menu.items.settings"), icon: "settings", path: adm_officing_settings_path }
    end

    items
  end
end
