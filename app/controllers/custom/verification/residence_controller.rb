require_dependency Rails.root.join("app", "controllers", "verification", "residence_controller").to_s

class Verification::ResidenceController < ApplicationController
  include HasRegisteredAddress

  def new
    current_user_attributes = current_user.attributes.transform_keys(&:to_sym).slice(*allowed_params)

    if current_user.registered_address.present?
      params[:form_registered_address_city_id] = current_user.registered_address.registered_address_city_id
      params[:form_registered_address_street_id] = current_user.registered_address.registered_address_street_id
      params[:form_registered_address_id] = current_user.registered_address.id
    end

    @residence = Verification::Residence.new(current_user_attributes)
  end

  def create
    @residence = Verification::Residence.new(
      residence_params.merge(user: current_user, registered_address_id: params[:form_registered_address_id])
    )
    process_temp_attributes_for(@residence)

    if @residence.save
      NotificationServices::NewManualVerificationRequestNotifier.call(current_user.id) # remove unless manual
      redirect_to account_path, notice: t("custom.verification.residence.create.flash.success_manual")
    else
      render :new #, alert: t("custom.verification.residence.create.flash.error")
    end
  end

  private

    def allowed_params
      [
        :first_name, :last_name, :gender, :date_of_birth,
        :city_name, :plz, :street_name, :street_number, :street_number_extension,
        :document_type, :document_last_digits,
        :terms_data_storage, :terms_data_protection, :terms_general,
        :registered_address_id, :terms_of_service
      ]
    end
end
