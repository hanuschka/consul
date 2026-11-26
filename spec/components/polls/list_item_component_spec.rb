require "rails_helper"

describe Polls::ListItemComponent, type: :component do
  it "shows the image credit on the poll tile" do
    poll = create(:poll)
    image = poll.build_image(user: create(:user), credits: "©Stadt Rheinfelden (Baden)")
    image.attachment.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
    image.save!(validate: false)

    render_inline(described_class.new(poll: poll.reload))

    expect(page).to have_css(".image-credit-label[title='©Stadt Rheinfelden (Baden)']", count: 1,
                             text: "©Stadt Rheinfelden (Baden)")
    expect(page).to have_css(".image-credit-label .show-for-sr")
  end
end
