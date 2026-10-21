require "rails_helper"

describe RelayState do
  let!(:expired) { RelayState.create!(token: "expired", created_at: 61.minutes.ago) }
  let!(:active) { RelayState.create!(token: "active", created_at: 59.minutes.ago) }

  it "counts relay states younger than an hour as active" do
    expect(RelayState.active).to eq([active])
  end

  it "counts relay states older than an hour as expired" do
    expect(RelayState.expired).to eq([expired])
  end
end
