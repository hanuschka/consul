require "rails_helper"

describe "Image credits in CSV exports" do
  def attach_image(imageable, credits:)
    image = imageable.build_image(user: create(:user), credits: credits)
    image.attachment.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
    image.save!(validate: false)
  end

  def parse(csv)
    CSV.parse(csv, col_sep: ";", headers: true)
  end

  it "exports the credit of a proposal image" do
    proposal = create(:proposal)
    attach_image(proposal, credits: "©Stadt Rheinfelden (Baden)")

    row = parse(CsvServices::ProposalsExporter.new(Proposal.where(id: proposal.id)).call).first

    expect(row["image_credits"]).to eq "©Stadt Rheinfelden (Baden)"
  end

  it "exports the credit of a budget investment image" do
    investment = create(:budget_investment)
    attach_image(investment, credits: "©name_stock.adobe.com")

    csv = CsvServices::BudgetInvestmentsExporter.new(Budget::Investment.where(id: investment.id), "example.org").call

    expect(parse(csv).first["Bildnachweis"]).to eq "©name_stock.adobe.com"
  end
end
