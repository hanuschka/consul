require "rails_helper"

describe "Homepage header image credits", type: :request do
  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
  end

  it "shows the credit of the legacy header card image" do
    card = Widget::Card.create!(header: true, title: "header_large")
    image = card.build_image(user: create(:user), credits: "©name_stock.adobe.com")
    image.attachment.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
    image.save!(validate: false)

    get root_path

    expect(Capybara.string(response.body)).to have_css(".homepage-image-header .image-credit-label",
                                                       count: 1, text: "©name_stock.adobe.com")
  end
end
