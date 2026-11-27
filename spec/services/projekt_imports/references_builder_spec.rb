require "rails_helper"

describe ProjektImports::ReferencesBuilder do
  describe ".fetch_content_block_templates" do
    before do
      allow(ContentBlockTemplates::Catalogue).to receive(:call).with(section: "general").and_return(
        [
          {
            "category" => { "id" => 1, "name_en" => "Basics" },
            "templates" => [
              { "id" => 1, "hidden" => false, "hidden_until" => nil },
              { "id" => 2, "hidden" => true, "hidden_until" => nil },
              { "id" => 3, "hidden" => false, "hidden_until" => 1.week.from_now.to_date.iso8601 }
            ]
          },
          {
            "category" => { "id" => 2, "name_en" => "Hero" },
            "templates" => [
              { "id" => 4, "hidden" => false, "hidden_until" => 1.day.ago.to_date.iso8601 }
            ]
          }
        ]
      )
    end

    it "never offers a template that is hidden in the selector, for good or until a date" do
      offered_ids = ProjektImports::ReferencesBuilder.fetch_content_block_templates.map { |template| template["id"] }

      expect(offered_ids).to eq [1, 4]
    end

    it "tags every template with its category" do
      categories =
        ProjektImports::ReferencesBuilder
          .fetch_content_block_templates
          .map { |template| template.slice("category_id", "category_name") }

      expect(categories).to eq [
        { "category_id" => 1, "category_name" => "Basics" },
        { "category_id" => 2, "category_name" => "Hero" }
      ]
    end
  end
end
