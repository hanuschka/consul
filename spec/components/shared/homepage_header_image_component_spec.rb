require "rails_helper"

describe Shared::HomepageHeaderImageComponent, type: :component do
  def upload(name, fixture, width:, height:)
    image = SiteCustomization::Image.find_or_initialize_by(name: name)
    image.image.attach(io: file_fixture(fixture).open, filename: fixture)
    image.save!
    image.image.blob.update!(metadata: { "analyzed" => true, "width" => width, "height" => height })
    image.image
  end

  def candidates(srcset)
    srcset.split(", ").map do |candidate|
      url, descriptor = candidate.split(" ")
      variation = ActiveStorage::Variation.decode(url.split("/")[-2])
      { width: descriptor.to_i, transformations: variation.transformations }
    end
  end

  def desktop_candidates
    candidates(page.find("img", visible: :all)[:srcset])
  end

  def mobile_candidates
    candidates(page.find("source", visible: :all)[:srcset])
  end

  it "offers a 3840 px PNG header to high-resolution desktop screens at full width" do
    desktop = upload("header_image", "clippy.png", width: 3840, height: 1400)

    render_inline(described_class.new(desktop_attachment: desktop))

    expect(desktop_candidates.map { |c| c[:width] }).to eq [960, 1440, 1920, 2880, 3840]
    expect(desktop_candidates.last[:transformations]).to include(resize_to_limit: [3840, nil], saver: { quality: 90 })
  end

  it "offers a 1080 × 1450 mobile header at its full resolution" do
    desktop = upload("header_image", "clippy.png", width: 3840, height: 1400)
    mobile = upload("mobile_header_image", "clippy.jpg", width: 1080, height: 1450)

    render_inline(described_class.new(desktop_attachment: desktop, mobile_attachment: mobile))

    expect(page.find("source", visible: :all)[:media]).to eq "(max-width: 750px)"
    expect(mobile_candidates.map { |c| c[:width] }).to eq [480, 720, 1080]
    expect(mobile_candidates.last[:transformations]).to include(resize_to_limit: [1080, nil], format: :jpeg)
  end

  it "offers smaller variants and caps the displayed width for normal-resolution screens" do
    desktop = upload("header_image", "clippy.png", width: 4000, height: 1583)

    render_inline(described_class.new(desktop_attachment: desktop))

    img = page.find("img", visible: :all)
    expect(desktop_candidates.map { |c| c[:width] }).to include(960, 1440, 1920)
    expect(img[:sizes]).to eq "(min-width: 1920px) 1920px, (min-width: 1769px) 100vw, 1769px"
    expect(candidates("#{img[:src]} 0w").first[:transformations]).to include(resize_to_limit: [1920, nil])
  end

  it "does not offer variants wider than 3840 px" do
    desktop = upload("header_image", "clippy.png", width: 8000, height: 1767)

    render_inline(described_class.new(desktop_attachment: desktop))

    expect(desktop_candidates.map { |c| c[:width] }.max).to eq 3840
  end

  it "uses the desktop image on mobile when there is no mobile image" do
    desktop = upload("header_image", "clippy.png", width: 4000, height: 1583)

    render_inline(described_class.new(desktop_attachment: desktop))

    expect(mobile_candidates.map { |c| c[:width] }).to eq [480, 720, 1080, 1440, 2160, 2880, 3840]
    expect(page.find("source", visible: :all)[:sizes]).to eq "1618px"
  end

  it "renders nothing without an image" do
    render_inline(described_class.new(desktop_attachment: SiteCustomization::Image.new.image))

    expect(page).not_to have_css("picture", visible: :all)
  end
end
