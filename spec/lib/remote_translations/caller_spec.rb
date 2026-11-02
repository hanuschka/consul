require "rails_helper"

describe RemoteTranslations::Caller do
  let(:source) { MachineTranslation.source_locale }
  let(:target) { (MachineTranslation.translatable_locales - [source]).first }
  let(:body) { %(<p>Gefördert von</p><p><img src="/logos.png" alt="Logos der Förderer" title="Förderer &amp; Partner"></p>) }
  let(:block) { Globalize.with_locale(source) { create(:site_customization_content_block, body: body) } }

  before do
    allow(Deepl).to receive(:configured?).and_return(true)
    allow_any_instance_of(RemoteTranslation).to receive(:enqueue_remote_translation)
    allow_any_instance_of(Deepl::Client).to receive(:translate) do |_client, texts, **|
      texts.map { |text| text.to_s.sub("Gefördert von", "Funded by").sub("Logos der Förderer", "Sponsor logos").sub("Förderer &amp; Partner", "Sponsors &amp; partners") }
    end
  end

  def translate!
    RemoteTranslation.where(remote_translatable: block).delete_all
    remote_translation = RemoteTranslation.create!(remote_translatable: block, locale: target.to_s)
    described_class.new(remote_translation, source_locale: source).call
  end

  it "translates image alt and title texts along with the text" do
    translate!

    translated = Globalize.with_locale(target) { block.reload.body }
    image = Nokogiri::HTML5.fragment(translated).at_css("img")

    expect(translated).to include("Funded by")
    expect(image["alt"]).to eq "Sponsor logos"
    expect(image["title"]).to eq "Sponsors & partners"
    expect(image["src"]).to eq "/logos.png"
  end

  it "leaves the source text untouched" do
    translate!

    expect(Globalize.with_locale(source) { block.reload.body }).to include(%(alt="Logos der Förderer"))
  end
end
