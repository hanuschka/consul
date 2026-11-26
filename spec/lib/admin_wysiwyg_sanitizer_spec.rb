require "rails_helper"

describe AdminWYSIWYGSanitizer do
  describe "JS mirror in studio/utils/htmlUtils.js" do
    let(:js_allowlist) do
      Rails.root
        .join("app/assets/javascripts/studio/utils/htmlUtils.js")
        .read[/ADMIN_WYSIWYG_ALLOWLIST = \{(.*?)\n\};/m, 1]
    end

    def js_list(key)
      js_allowlist[/#{key}: \[(.*?)\]/m, 1].scan(/"([^"]+)"/).flatten.uniq
    end

    it "allows the same tags" do
      expect(js_list("allowedTags")).to match_array(described_class.new.allowed_tags.uniq)
    end

    it "allows the same attributes" do
      expect(js_list("allowedAttributes")).to match_array(described_class.new.allowed_attributes.uniq)
    end
  end
end
