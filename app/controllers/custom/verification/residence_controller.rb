require_dependency Rails.root.join("app", "controllers", "verification", "residence_controller").to_s

class Verification::ResidenceController < ApplicationController
  def create
    @residence = Verification::Residence.new(residence_params.merge(user: current_user))
    verification_mode = params[:residence][:verification_mode]

    last_budget = Budget.joins(projekt: :page).where(budgets: { projekts: { site_customization_pages: { status: 'published' } } }).last
    last_budget_link = page_path(last_budget.projekt.page.slug,
                                 selected_phase: "#{last_budget.projekt.budget_phase.id}",
                                 anchor: "filter-subnav")


    if verification_mode == "manual" && @residence.save_manual_verification
      if last_budget.present?
        redirect_to last_budget_link, notice: t("custom.verification.residence.create.flash.success_manual")
      else
        redirect_to account_path, notice: t("custom.verification.residence.create.flash.success_manual")
      end

    elsif verification_mode != "manual" && @residence.save
      if last_budget.present?
        redirect_to last_budget_link, notice: t("verification.residence.create.flash.success")
      else
        redirect_to verified_user_path, notice: t("verification.residence.create.flash.success")
      end

    else
      render :new
    end
  end

  private

    def allowed_params
      [
        :document_number, :document_type, :date_of_birth, :postal_code, :terms_of_service,
        :first_name, :last_name, :street_name, :street_number,
        :plz, :city_name, :gender, :document_last_digits
      ]
    end
end
