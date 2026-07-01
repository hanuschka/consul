class Users::SystemUserService < ApplicationService
  LEGACY_USERNAME = "masterportal".freeze
  SITE_LOGO_NAME = "logo_header".freeze
  DEFAULT_NAME = "System".freeze

  def call
    existing = User.find_by(system_user: true)
    return existing if existing.present?

    user = upgrade_or_build_user
    user.save!(validate: false)

    attach_site_logo(user)

    user
  end

  private

    def upgrade_or_build_user
      user = User.find_by(username: LEGACY_USERNAME) || build_user

      user.system_user = true
      user.username = display_name if user.username.blank? || user.username == LEGACY_USERNAME
      user.skip_confirmation! if user.confirmed_at.blank?

      user
    end

    def build_user
      User.new(
        email: "system@system.consul",
        password: SecureRandom.hex(32)
      )
    end

    def display_name
      name = Setting["org_name"].presence || DEFAULT_NAME

      name.truncate(User.username_max_length)
    end

    def attach_site_logo(user)
      logo = SiteCustomization::Image.find_by(name: SITE_LOGO_NAME)
      return if logo.nil? || !logo.image.attached?

      user.image&.destroy

      image = Image.new(title: "avatar", user: user, imageable: user)
      image.attachment.attach(
        io: StringIO.new(logo.image.download),
        filename: logo.image.filename.to_s,
        content_type: logo.image.content_type
      )
      image.save!(validate: false)
    end
end
