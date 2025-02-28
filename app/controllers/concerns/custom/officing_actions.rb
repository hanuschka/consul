module OfficingActions
  extend ActiveSupport::Concern

  included do
    before_action :set_officing_manager
    before_action :set_offline_user, only: [:officing_desk]
  end

  def verify_user
    render "officing/shared/verify_user"
  end

  def find_or_create_user
    if params["skip_verification"].present?
      offline_user = User.create!(
        erased_at:                Time.current,
        email:                    nil,
        skip_password_validation: true,
        terms_data_storage:       "1",
        terms_data_protection:    "1",
        terms_general:            "1"
      )

      redirect_to action: :officing_desk, offline_user_id: offline_user.id

    else
      unique_stamp = User.new(user_params).prepare_unique_stamp

      if (unique_stamp.blank? ||
          params[:"date_of_birth(1i)"].blank? ||
          params[:"date_of_birth(2i)"].blank? ||
          params[:"date_of_birth(3i)"].blank?)
        flash.now[:error] = "Bitte stellen Sie sicher, dass alle Felder ausgefüllt sind"
        render :verify_user

      else
        offline_user = User.find_by(unique_stamp: unique_stamp)
        offline_user ||= User.find_by(
          first_name: user_params[:first_name],
          last_name: user_params[:last_name],
          plz: user_params[:plz],
          date_of_birth: Date.new(
            params[:"date_of_birth(1i)"].to_i,
            params[:"date_of_birth(2i)"].to_i,
            params[:"date_of_birth(3i)"].to_i
          ).beginning_of_day
        )
        offline_user ||= User.new

        if offline_user.new_record?
          offline_user.assign_attributes(user_params)
          offline_user.email = nil
          offline_user.verified_at = Time.current
          offline_user.erased_at = Time.current
          offline_user.password = "Aa1" + (0...17).map { ("a".."z").to_a[rand(26)] }.join
          offline_user.terms_data_storage = "1"
          offline_user.terms_data_protection = "1"
          offline_user.terms_general = "1"
          offline_user.unique_stamp = unique_stamp
          offline_user.geozone = Geozone.find_with_plz(params[:plz])
          offline_user.save!
        end

        offline_user.verify! if offline_user.verified_at.nil?

        redirect_to action: :officing_desk, offline_user_id: offline_user.id
      end
    end
  end

  private

    def user_params
      params
        .slice(:first_name, :last_name, :plz, :"date_of_birth(1i)", :"date_of_birth(2i)", :"date_of_birth(3i)")
        .permit(:first_name, :last_name, :plz, :date_of_birth)
    end

    def set_officing_manager
      @officing_manager = current_user.officing_manager
    end

    def set_offline_user
      @offline_user = User.find(params[:offline_user_id])
    end
end
