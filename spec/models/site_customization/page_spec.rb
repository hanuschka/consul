require "rails_helper"

describe SiteCustomization::Page do
  describe "#destroy" do
    let(:landing_page) do
      SiteCustomization::Page.create!(title: "Landing", slug: "landing", status: "published", landing: true)
    end

    it "unassigns visible and hidden projekts that use it as landing page" do
      visible_projekt = create(:projekt, landing_page: landing_page)
      hidden_projekt = create(:projekt, landing_page: landing_page)
      hidden_projekt.update_column(:hidden_at, Time.current)

      landing_page.destroy!

      expect(Projekt.with_hidden.find(visible_projekt.id).landing_page_id).to be nil
      expect(Projekt.with_hidden.find(hidden_projekt.id).landing_page_id).to be nil
    end
  end
end
