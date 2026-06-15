module Adm
  class HomepageController < Adm::BaseController
    HEX_COLOR_REGEX = /\A#[0-9a-fA-F]{6}\z/
    NAVIGATION_LINK_COLOR_KEY = "extended_option.general.homepage_navigation_link_color".freeze
    DEFAULT_NAVIGATION_LINK_COLOR = "#000000".freeze

    def show
      authorize [:adm, :homepage]
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.homepage") }
      ]
    end

    def update_navigation_link_color
      authorize [:adm, :homepage], :update?

      raw_color = params[:color].to_s.strip
      new_color = raw_color.presence || DEFAULT_NAVIGATION_LINK_COLOR

      unless new_color.match?(HEX_COLOR_REGEX)
        render json: { ok: false, errors: ["Invalid color format"] },
               status: :unprocessable_entity
        return
      end

      setting = Setting.find_by!(key: NAVIGATION_LINK_COLOR_KEY)
      setting.update!(value: new_color)

      # Invalidate the per-request settings cache populated by
      # Setting.all_settings_hash so subsequent reads pick up the new value.
      Current.settings = nil

      render json: { ok: true, color: new_color }
    end
  end
end
