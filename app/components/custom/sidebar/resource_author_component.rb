class Sidebar::ResourceAuthorComponent < ApplicationComponent
  attr_reader :resource, :user

  def initialize(resource:)
    @resource = resource
    @user = resource.author
  end

  private

    def on_behalf_of?
      resource.on_behalf_of.present?
    end

    def show_background_image?
      !on_behalf_of? &&
        user.background_image.attached?
    end

    def show_user_avatar?
      !on_behalf_of? &&
        user.image&.variant(:popup).present?
    end

    def author_path
      on_behalf_of? ? "#" : user_path(user)
    end
end
