require "rails_helper"

describe Resources::ListItemComponent, type: :component do
  let(:poll) { create(:poll) }
  let(:credits) { "©name_stock.adobe.com" }

  before do
    image = poll.build_image(user: create(:user), credits: credits)
    image.attachment.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
    image.save!(validate: false)
    poll.reload
  end

  def render_tile(label_row: false)
    render_inline(described_class.new(title: poll.title, description: "", resource: poll)) do |c|
      c.with_image(image: poll.image, resource: poll)
      c.with_image_overlay_item { "Label" } if label_row
    end
  end

  it "puts the credit into the label row once when the tile has one" do
    render_tile(label_row: true)

    expect(page).to have_css(".image-credit-label", count: 1)
    expect(page).to have_css(".resource-item--image-overlay-item.-with-credit .image-credit-label", text: credits)
  end

  it "shows the credit on the image when the tile has no label row" do
    render_tile

    expect(page).to have_css(".resource-item--image-container > .image-credit-label", count: 1, text: credits)
  end

  it "renders no credit label for a concealed image" do
    poll.image.update_column(:concealed, true)

    render_tile

    expect(page).not_to have_css(".image-credit-label")
  end

  context "without a credit" do
    let(:credits) { nil }

    it "renders no credit label" do
      render_tile(label_row: true)

      expect(page).to have_css(".resource-image--main")
      expect(page).not_to have_css(".image-credit-label")
      expect(page).not_to have_css(".-with-credit")
    end
  end
end
