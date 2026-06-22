class Adm::SystemUserInfoComponent < ApplicationComponent
  def initialize(user:, kind: :system, show_edit_link: true, size: :default, linkable: false, edit_url: nil)
    @user = user
    @kind = kind
    @show_edit_link = show_edit_link
    @size = size
    @linkable = linkable
    @edit_url = edit_url
  end

  private

    attr_reader :user, :kind, :size

    def name
      user.full_name
    end

    def label
      if api_client_kind?
        t(".api_client_label")
      elsif small?
        t(".system_user_tag")
      else
        t(".label")
      end
    end

    def css_classes
      class_names("adm-system-user-info", "-api-client": api_client_kind?, "-small": small?)
    end

    def api_client_kind?
      kind == :api_client
    end

    def small?
      size == :small
    end

    def show_system_user_tag?
      !api_client_kind? && !small?
    end

    def edit_url
      return @edit_url if @edit_url.present?

      if api_client_kind?
        helpers.edit_adm_user_path(user)
      else
        helpers.edit_adm_system_user_path
      end
    end

    def show_edit_link?
      @show_edit_link && !api_client_kind? && !small?
    end

    def linkable?
      @linkable && small? && edit_url.present?
    end

    def wrapper_tag
      linkable? ? :a : :div
    end

    def wrapper_options
      options = { class: css_classes }

      if linkable?
        options[:href] = edit_url
        options[:target] = "_blank"
        options[:rel] = "noopener"
      end

      options
    end
end
