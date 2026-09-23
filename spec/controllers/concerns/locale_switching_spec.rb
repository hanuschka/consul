require "rails_helper"

describe LocaleSwitching do
  let(:controller_class) do
    Class.new do
      include LocaleSwitching

      attr_accessor :user

      def current_user
        user
      end
    end
  end

  let(:controller) { controller_class.new }

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
