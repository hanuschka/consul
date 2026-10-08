require "rails_helper"

describe SiteCustomization::ContentBlock do
  describe "e-mail links in the body" do
    let(:projekt) { create(:projekt) }

    def create_block(body)
      SiteCustomization::ContentBlock.create!(
        name: "custom",
        key: "projekt_sidebar_#{projekt.id}",
        locale: I18n.default_locale,
        projekt: projekt,
        body: body
      )
    end

    it "stores a bare e-mail address link target as a mailto link" do
      block = create_block('<p><a href="info@example.org">info@example.org</a></p>')

      expect(block.reload.body).to include('href="mailto:info@example.org"')
    end

    it "does not flag the repaired link as stripped content" do
      block = create_block('<p><a href="info@example.org">info@example.org</a></p>')

      expect(block.body_stripped?).to be false
    end

    it "keeps web links unchanged" do
      block = create_block('<p><a href="https://example.org/kontakt" target="_blank">web</a></p>')

      expect(block.reload.body).to include('href="https://example.org/kontakt"')
    end
  end
end
