require_dependency Rails.root.join("app", "controllers", "users", "confirmations_controller").to_s

class Users::ConfirmationsController < Devise::ConfirmationsController
  protected


    def after_confirmation_path_for(resource_name, resource)
      sign_in(resource)

      if signed_in?(resource_name)
        last_budget = Budget.joins(projekt: :page)
                            .where(budgets: { projekts: { site_customization_pages: { status: 'published' } } })
                            .last

        if last_budget.present?
          page_path(last_budget.projekt.page.slug,
                    selected_phase: last_budget.projekt.budget_phase.id.to_s,
                    anchor: "filter-subnav")
        else
          signed_in_root_path(resource)
        end
      else
        new_session_path(resource_name)
      end
    end
end
