require "rails_helper"

describe "registered_addresses:rematch" do
  let(:task) { Rake::Task["registered_addresses:rematch"] }
  let(:old_address) do
    create(:registered_address, street_name: "Altstraße", street_number: "1", plz: "50667", city_name: "Köln")
  end
  let!(:new_address) do
    create(:registered_address, street_name: "Heidestraße", street_number: "17", plz: "51147", city_name: "Köln")
  end

  before { task.reenable }

  def drifted_user(street_name: "Heidestraße", street_number: "17", plz: 51147)
    create(:user).tap do |user|
      user.update_columns(registered_address_id: old_address.id, street_name: street_name,
                          street_number: street_number, plz: plz, city_name: "Köln")
    end
  end

  def run_with_answers(*answers)
    allow($stdin).to receive(:gets).and_return(*answers.map { |answer| "#{answer}\n" })
    expect { task.invoke }.to output(/Applied:/).to_stdout
  end

  it "relinks a drifted user to the register entry matching the typed address once approved" do
    user = drifted_user

    run_with_answers("y")

    expect(user.reload.registered_address_id).to eq(new_address.id)
    expect(user.street_name).to eq("Heidestraße")
    expect(user.audits.last.comment).to eq("registered_addresses:rematch")
  end

  it "asks again until the answer is y, n or q" do
    user = drifted_user

    run_with_answers("yes", "", "y")

    expect(user.reload.registered_address_id).to eq(new_address.id)
    expect($stdin).to have_received(:gets).exactly(3).times
  end

  it "shows the position among all drifted users" do
    drifted_user
    drifted_user
    allow($stdin).to receive(:gets).and_return("n\n")

    expect { task.invoke }.to output(%r{Drifted users: 2.*1/2 Apply\?.*2/2 Apply\?}m).to_stdout
  end

  it "clears the link when the typed address is not in the register" do
    user = drifted_user(street_name: "Lessingstraße", street_number: "10")

    run_with_answers("y")

    expect(user.reload.registered_address_id).to be_nil
    expect(user.street_name).to eq("Lessingstraße")
  end

  it "leaves a user alone when the change is declined" do
    user = drifted_user

    run_with_answers("n")

    expect(user.reload.registered_address_id).to eq(old_address.id)
  end

  it "does not ask about users whose link matches the typed address" do
    user = create(:user)
    user.update_columns(registered_address_id: new_address.id, street_name: "Heidestr.", street_number: "17",
                        plz: 51147, city_name: "Köln")
    allow($stdin).to receive(:gets)

    expect { task.invoke }.to output(/Drifted users: 0/).to_stdout
    expect($stdin).not_to have_received(:gets)
  end

  it "stops at q without touching the rest" do
    first = drifted_user
    second = drifted_user

    run_with_answers("q", "y")

    expect([first, second].map { |user| user.reload.registered_address_id }).to all(eq(old_address.id))
  end
end
