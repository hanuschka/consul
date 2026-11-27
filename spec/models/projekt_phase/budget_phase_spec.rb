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

  describe "#start_date and #end_date" do
    let(:budget) { phase.reload.budget }

    def stage(kind)
      budget.phases.find_by!(kind: kind)
    end

    before do
      budget.phases.update_all(enabled: false)
      stage("accepting").update_columns(enabled: true,
                                        starts_at: Time.zone.local(2026, 10, 1),
                                        ends_at: Time.zone.local(2026, 10, 15))
      stage("balloting").update_columns(enabled: true,
                                        starts_at: Time.zone.local(2026, 10, 15),
                                        ends_at: Time.zone.local(2026, 11, 14))
      stage("finished").update_columns(enabled: true,
                                       starts_at: Time.zone.local(2026, 11, 14),
                                       ends_at: Time.zone.local(2026, 12, 14))
      phase.update_columns(active: true, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 11, 7))
      phase.reload
    end

    it "starts with the first enabled stage, ignoring the stored date" do
      expect(phase.start_date).to eq(Date.new(2026, 10, 1))
    end

    it "ends on the last day of the last enabled stage, ignoring the stored date" do
      expect(phase.end_date).to eq(Date.new(2026, 12, 13))
    end

    it "skips disabled stages" do
      stage("accepting").update_column(:enabled, false)
      phase.reload

      expect(phase.start_date).to eq(Date.new(2026, 10, 15))
    end

    it "follows an extended stage" do
      stage("finished").update_column(:ends_at, Time.zone.local(2026, 12, 21))
      phase.reload

      expect(phase.end_date).to eq(Date.new(2026, 12, 20))
    end

    it "is current until the last day of the derived range" do
      travel_to(Time.zone.local(2026, 12, 13, 12)) do
        expect(phase.current?).to be(true)
        expect(phase.expired?).to be(false)
      end

      travel_to(Time.zone.local(2026, 12, 14, 12)) do
        expect(phase.current?).to be(false)
        expect(phase.expired?).to be(true)
      end
    end

    it "falls back to the stored dates without a budget" do
      budget.destroy!
      phase.reload

      expect(phase.start_date).to eq(Date.new(2026, 1, 1))
      expect(phase.end_date).to eq(Date.new(2026, 11, 7))
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
