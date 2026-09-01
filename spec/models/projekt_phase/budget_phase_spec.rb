require "rails_helper"

describe ProjektPhase::BudgetPhase do
  # The shared factory sets only the type column, so STI never instantiates the subclass and the
  # after_create hook creates no settings at all. Build the subclass directly instead.
  let(:phase) { ProjektPhase::BudgetPhase.create!(projekt: create(:projekt)) }

  def hide_comments_count_order
    phase.settings.find_by!(key: "feature.resource.hide_comments_count_order").update!(value: "active")
    phase.reload
  end

  describe "#investment_orders" do
    it "offers every order, comment count included, while the setting is off" do
      expect(phase.investment_orders).to eq(Budget::Investment::DEFAULT_ORDERS)
      expect(phase.investment_orders).to include("comments_count")
    end

    it "drops only the comment-count order while the setting is on" do
      hide_comments_count_order

      expect(phase.investment_orders).not_to include("comments_count")
      expect(phase.investment_orders).to eq(Budget::Investment::DEFAULT_ORDERS - ["comments_count"])
    end

    it "leaves the shared constant untouched" do
      hide_comments_count_order
      phase.investment_orders

      expect(Budget::Investment::DEFAULT_ORDERS).to include("comments_count")
    end

    it "stops offering a stored default order that has been hidden" do
      phase.settings
        .find_by!(key: "selectable_setting.general.default_order")
        .update!(value: "comments_count")
      hide_comments_count_order

      expect(phase.investment_orders).not_to include("comments_count")
      expect(phase.investment_orders).to be_present
    end
  end

  describe "the setting itself" do
    it "is off for a newly created phase" do
      setting = phase.settings.find_by(key: "feature.resource.hide_comments_count_order")

      expect(setting).to be_present
      expect(setting.value).to be_blank
      expect(phase.feature?("resource.hide_comments_count_order")).to be_falsey
    end
  end
end
