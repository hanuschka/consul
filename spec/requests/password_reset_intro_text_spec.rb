require "rails_helper"

describe "Password reset intro text", type: :request do
  let(:platform_default) { I18n.t("custom.users.shared.auth_page.legend") }

  def set_block(key, body)
    SiteCustomization::ContentBlock.custom_block_for(key).update!(body: body)
    Current.custom_content_blocks = nil
  end

  describe "with a text configured" do
    before { set_block("auth_page_legend.passwords", "<p>Hier fordern Sie ein neues Passwort an.</p>") }

    it "shows it instead of the platform default" do
      get new_user_password_path

      expect(response.body).to include("Hier fordern Sie ein neues Passwort an.")
      expect(response.body).not_to include(platform_default)
    end

    it "keeps the formatting of the stored text" do
      set_block("auth_page_legend.passwords", "<p>Erste Zeile</p><p><strong>Zweite Zeile</strong></p>")

      get new_user_password_path

      expect(response.body).to include("<strong>Zweite Zeile</strong>")
    end
  end

  describe "with the text empty" do
    it "falls back to the platform default, like the sign-in page" do
      get new_user_password_path

      expect(response.body).to include(platform_default)
    end
  end

  describe "independence from the sign-in text" do
    it "leaves the sign-in page on its own text when the reset text is set" do
      set_block("auth_page_legend.sessions", "<p>Willkommen zurück.</p>")
      set_block("auth_page_legend.passwords", "<p>Neues Passwort anfordern.</p>")

      get new_user_session_path
      expect(response.body).to include("Willkommen zurück.")
      expect(response.body).not_to include("Neues Passwort anfordern.")

      get new_user_password_path
      expect(response.body).to include("Neues Passwort anfordern.")
      expect(response.body).not_to include("Willkommen zurück.")
    end

    it "keeps the sign-in fallback when only the reset text is set" do
      set_block("auth_page_legend.passwords", "<p>Neues Passwort anfordern.</p>")

      get new_user_session_path

      expect(response.body).to include(platform_default)
    end
  end
end
