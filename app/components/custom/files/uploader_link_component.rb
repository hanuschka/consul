class Files::UploaderLinkComponent < ApplicationComponent
  AVATAR_VARIANT = :thumb2

  def initialize(user:)
    @user = user
  end

  def render?
    user.present?
  end

  private

    attr_reader :user

    def profile_url
      helpers.user_path(user)
    end

    def avatar_image
      return nil if !user.image&.attached?

      user.image.variant(AVATAR_VARIANT)
    end

    def placeholder_letter
      user.first_letter_of_name
    end
end
