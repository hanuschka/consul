class Adm::SystemUserInfoComponent < ApplicationComponent
  def initialize(user:, show_edit_link: true)
    @user = user
    @show_edit_link = show_edit_link
  end

  private

    attr_reader :user, :show_edit_link

    def name
      user.name
    end

    def edit_url
      helpers.edit_adm_system_user_path
    end

    def show_edit_link?
      @show_edit_link
    end
end
