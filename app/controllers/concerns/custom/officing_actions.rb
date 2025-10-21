module OfficingActions
  extend ActiveSupport::Concern

  included do
    include HasRegisteredAddress

    before_action :set_officing_manager
    before_action :set_offline_user, only: [:officing_desk]
  end

  def verify_user
    @offline_user = User.new
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
      @offline_user = User.new(user_params)
      process_temp_attributes_for(@offline_user)

      unique_stamp = @offline_user.prepare_unique_stamp

      if unique_stamp.blank?
        flash.now[:error] = "Bitte stellen Sie sicher, dass alle Felder ausgefüllt sind"
        render "officing/shared/verify_user"

      else
        existing_user_with_unique_stamp = User.find_by(unique_stamp: unique_stamp)

        @offline_user = existing_user_with_unique_stamp if existing_user_with_unique_stamp.present?

        if (Setting["feature.melderegister"] && @offline_user.send(:residency_valid?)) || params["mark_as_verified"].present?
          @offline_user.verified_at ||= Time.current
          @offline_user.unique_stamp = unique_stamp
        end

        if @offline_user.new_record?
          @offline_user.email = nil
          @offline_user.erased_at = Time.current
          @offline_user.password = "Aa1" + (0...17).map { ("a".."z").to_a[rand(26)] }.join
          @offline_user.terms_data_storage = "1"
          @offline_user.terms_data_protection = "1"
          @offline_user.terms_general = "1"
          @offline_user.save!
        end

        redirect_to action: :officing_desk, offline_user_id: @offline_user.id
      end
    end
  end

  private

    def user_params
      set_address_attributes

      params.require(:user).permit(:first_name, :last_name,
                                   :city_name, :plz, :street_name, :street_number, :street_number_extension,
                                   :registered_address_id,
                                   :gender, :date_of_birth)
    end

    def set_officing_manager
      @officing_manager = current_user.officing_manager
    end

    def set_offline_user
      @offline_user = User.find(params[:offline_user_id])
    end
end
