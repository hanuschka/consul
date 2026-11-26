require "rails_helper"

describe ProjektImports::PromptBuilder do
  let(:templates) do
    (1..12).map do |id|
      { "id" => id, "name" => "template-#{id}", "description" => "Description #{id}", "content" => "<p>#{id}</p>" }
    end
  end

  let(:refs) { { "content_block_templates" => templates } }

  def build_prompt(random: Random.new(1))
    ProjektImports::PromptBuilder.new(
      base_prompt: "Base prompt",
      refs: refs,
      response_language: "English",
      random: random
    ).call
  end

  def offered_template_ids(prompt)
    prompt.scan(/^  (\d+) — template-/).flatten.map(&:to_i)
  end

  describe "template list" do
    it "offers every template, in a different order for two imports" do
      first_order = offered_template_ids(build_prompt(random: Random.new(1)))
      second_order = offered_template_ids(build_prompt(random: Random.new(2)))

      expect(first_order).to match_array(templates.map { |template| template["id"] })
      expect(second_order).to match_array(first_order)
      expect(second_order).not_to eq first_order
    end
  end
end
