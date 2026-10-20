require "rails_helper"

describe Projekts::Copying::ReferenceRewirer do
  let(:copy) { create(:projekt) }
  let(:id_map) { Projekts::Copying::IdMap.new }

  def image_html(filename)
    %(<p><img src="/rails/active_storage/blobs/redirect/source-key/#{filename}" alt=""></p>)
  end

  it "rewrites the image URLs in every translation of the copied content blocks" do
    content_block = create(:site_customization_content_block, projekt: copy, body: image_html("bild.png"))
    Globalize.with_locale(:de) { content_block.update!(body: image_html("bild-de.png")) }
    id_map.register_blob(double(key: "source-key"), double(key: "copy-key"))

    Projekts::Copying::ReferenceRewirer.call(bundle: {}, copy: copy, id_map: id_map)

    bodies = content_block.translations.reload.map(&:body)
    expect(bodies.size).to eq(2)
    expect(bodies).to all(include("/copy-key/"))
    expect(bodies.join).not_to include("source-key")
  end
end
