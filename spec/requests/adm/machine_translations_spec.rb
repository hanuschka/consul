require "rails_helper"

describe "The machine translation page in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:target_locale) { MachineTranslation.translatable_locales.first.to_s }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(MachineTranslation::Stats).to receive(:usage).and_return(
      "character_count" => 1_000, "character_limit" => 500_000
    )
  end

  describe "access" do
    it "denies a signed-out visitor" do
      get adm_machine_translations_path

      expect(response).not_to have_http_status(:ok)
    end

    it "denies a regular user" do
      login_as(create(:user))

      get adm_machine_translations_path

      expect(response).not_to have_http_status(:ok)
    end

    it "allows an administrator" do
      login_as(admin)

      get adm_machine_translations_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("adm.machine_translations.index.title"))
    end
  end

  describe "index" do
    before { login_as(admin) }

    it "shows usage and the queue" do
      get adm_machine_translations_path

      expect(response.body).to include(I18n.t("adm.machine_translations.index.usage.title"))
      expect(response.body).to include(I18n.t("adm.machine_translations.index.queue.title"))
    end

    it "lists failed translations", :delay_jobs do
      proposal = create(:proposal)
      RemoteTranslation.create!(remote_translatable: proposal, locale: target_locale,
                                error_message: "Deepl::ApiError: boom")

      get adm_machine_translations_path

      expect(response.body).to include("Deepl::ApiError: boom")
    end

    it "shows the empty state when nothing has failed" do
      get adm_machine_translations_path

      expect(response.body).to include(I18n.t("adm.machine_translations.index.failures.none_title"))
    end
  end

  describe "purge" do
    before { login_as(admin) }

    it "rejects an unknown locale" do
      delete adm_machine_translation_path("xx")

      expect(response).to redirect_to(adm_machine_translations_path)
      expect(flash[:alert]).to eq(I18n.t("adm.machine_translations.flash.unknown_locale"))
    end

    it "deletes machine rows but keeps the authored row" do
      proposal = create(:proposal)
      authored = proposal.translations.order(:created_at, :id).first
      authored.update_columns(locale: target_locale, created_at: 2.days.ago)
      machine = proposal.translations.create!(locale: target_locale, title: "machine",
                                              description: "machine description",
                                              created_at: 1.hour.ago)

      delete adm_machine_translation_path(target_locale)

      expect(Proposal::Translation.unscoped.where(id: authored.id)).to exist
      expect(Proposal::Translation.unscoped.where(id: machine.id)).not_to exist
    end

    it "denies a regular user" do
      login_as(create(:user))

      delete adm_machine_translation_path(target_locale)

      expect(response).not_to have_http_status(:ok)
    end
  end
end
