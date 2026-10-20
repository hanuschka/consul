require "rails_helper"

describe LocaleSwitching do
  let(:controller_class) do
    Class.new do
      include LocaleSwitching

      attr_accessor :user, :request

      def current_user
        user
      end
    end
  end

  let(:controller) { controller_class.new }

  describe "#browser_locale" do
    before do
      controller.request = double(headers: { "Accept-Language" => "en-US,en;q=0.9,de;q=0.8" })
      set_setting("extended_feature.general.language_switcher_in_menu", true)
      set_setting("extended_feature.general.enable_google_translate", nil)
    end

    it "picks the browser language when the menu language switcher is on" do
      expect(controller.send(:browser_locale)).to eq(:en)
    end

    it "ignores the browser language when the menu language switcher is off" do
      set_setting("extended_feature.general.language_switcher_in_menu", nil)

      expect(controller.send(:browser_locale)).to be_nil
    end

    it "ignores the browser language when Google Translate replaces the switcher" do
      set_setting("extended_feature.general.enable_google_translate", true)

      expect(controller.send(:browser_locale)).to be_nil
    end
  end

  describe "#persist_user_locale" do
    it "stores the locale on a persisted user" do
      controller.user = create(:user, locale: "de")

      controller.send(:persist_user_locale, :en)

      expect(controller.user.reload.locale).to eq("en")
    end

    it "ignores an unsaved guest user" do
      controller.user = User.new(guest: true)

      expect { controller.send(:persist_user_locale, :en) }.not_to raise_error
    end

    it "ignores an anonymous visitor" do
      controller.user = nil

      expect { controller.send(:persist_user_locale, :en) }.not_to raise_error
    end

    it "does not write when the locale is unchanged" do
      controller.user = create(:user, locale: "en")

      expect(controller.user).not_to receive(:update_column)

      controller.send(:persist_user_locale, :en)
    end
  end
end
