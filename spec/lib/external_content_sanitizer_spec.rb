require "rails_helper"

describe ExternalContentSanitizer do
  subject(:sanitizer) { described_class.new }

  let(:frame) { '<iframe src="https://example.org/page"></iframe>' }

  describe "#sanitize" do
    it "removes embedded frames" do
      expect(sanitizer.sanitize("<p>Text</p>#{frame}")).to eq "<p>Text</p>"
    end

    it "removes images that load from another server" do
      html = '<p>Text</p><img src="https://example.org/pixel.png">' \
             '<img src="//example.org/pixel.png"><img src="/\\example.org/pixel.png">'

      expect(sanitizer.sanitize(html)).to eq "<p>Text</p>"
    end

    it "keeps images stored on the platform" do
      html = '<p><img src="/rails/active_storage/blobs/redirect/abc/photo.jpg" alt="Foto"></p>'

      expect(sanitizer.sanitize(html)).to eq html
    end
  end

  describe "#sanitize_params" do
    it "cleans every given field, however deeply it is nested" do
      params = ActionController::Parameters.new(
        proposal: {
          description: "<p>A</p>#{frame}",
          translations_attributes: { "0" => { locale: "de", description: "<p>B</p>#{frame}" } },
          documents: [{ summary: "<p>C</p>#{frame}" }]
        }
      )

      sanitizer.sanitize_params(params, %w[description summary])

      expect(params[:proposal][:description]).to eq "<p>A</p>"
      expect(params[:proposal][:translations_attributes]["0"][:description]).to eq "<p>B</p>"
      expect(params[:proposal][:documents].first[:summary]).to eq "<p>C</p>"
    end

    it "leaves other fields and fields without external content alone" do
      params = ActionController::Parameters.new(
        title: "<p>A</p>#{frame}", description: "Bänke & Tische < 5 Meter"
      )

      sanitizer.sanitize_params(params, %w[description])

      expect(params[:title]).to eq "<p>A</p>#{frame}"
      expect(params[:description]).to eq "Bänke & Tische < 5 Meter"
    end
  end
end
