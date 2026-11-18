require "rails_helper"

describe Deepl::Client do
  let(:sent_texts) { [] }

  before do
    allow(Deepl).to receive_messages(validate!: true, api_key: "key")
    allow(Deepl::CircuitBreaker).to receive(:guard!)
    allow(Deepl::CircuitBreaker).to receive(:record_success)
    allow(described_class).to receive(:post) do |_url, **options|
      texts = JSON.parse(options[:body])["text"]
      sent_texts.concat(texts)
      translations = texts.map { |text| { "text" => text.gsub("Absatz", "Paragraph") } }
      instance_double(HTTParty::Response, success?: true, parsed_response: { "translations" => translations })
    end
  end

  def translate(text)
    described_class.new.translate([text], target_locale: :en, source_locale: :de, tag_handling: "html").first
  end

  def long_page
    paragraphs = (1..2_600).map { |number| "<p>Absatz #{number}: %{name} wohnt in Jena-Lobeda.#{" Text" * 15}</p>" }
    %(<div class="page"><h2>Titel</h2>#{paragraphs.join}</div>)
  end

  it "translates a page above the per-text limit completely and keeps its structure" do
    page = long_page
    expect(page.bytesize).to be > 260_000

    translated = translate(page)

    expect(sent_texts.size).to be > 1
    expect(sent_texts).to all(satisfy { |text| text.to_json.bytesize < described_class::MAX_TEXT_BYTES })
    expect(translated).to eq page.gsub("Absatz", "Paragraph")
    expect(translated.scan("%{name}").size).to eq 2_600
  end

  it "never sends embedded images to DeepL and puts them back unchanged" do
    image = "data:image/png;base64,#{"iVBORw0KGgo" * 20_000}"
    page = %(<p>Absatz eins</p><p><img src="#{image}" alt="Logo"></p>)

    translated = translate(page)

    expect(sent_texts.join).not_to include("base64")
    expect(translated).to include(%(src="#{image}"))
    expect(translated).to include("Paragraph eins")
  end

  it "still sends text that merely contains data: as text" do
    translate("<p>Metadata:Absatz</p>")

    expect(sent_texts).to eq ["<p>Metadata:Absatz</p>"]
  end
end
