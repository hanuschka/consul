require "rails_helper"

describe IndividualGroupValue do
  let(:group_value) { create(:individual_group_value) }

  describe "#add_email" do
    it "stores an address that has no account" do
      expect(group_value.add_email("neu@example.org")).to be true

      expect(group_value.reload.auto_join_emails).to eq(["neu@example.org"])
      expect(group_value.users).to be_empty
    end

    it "adds the user directly when an account already exists" do
      user = create(:user, email: "vorhanden@example.org")

      group_value.add_email("vorhanden@example.org")

      expect(group_value.reload.users).to eq([user])
      expect(group_value.auto_join_emails).to be_empty
    end

    it "normalises case and surrounding whitespace" do
      group_value.add_email("  Gross@Example.ORG ")

      expect(group_value.reload.auto_join_emails).to eq(["gross@example.org"])
    end

    it "does not store the same address twice" do
      group_value.add_email("doppelt@example.org")

      expect { group_value.add_email("Doppelt@example.org") }
        .not_to change { group_value.reload.auto_join_emails.size }
    end

    it "rejects a blank address" do
      expect(group_value.add_email("  ")).to be false
    end
  end

  describe "#add_user" do
    it "does not create a second membership for the same user" do
      user = create(:user)
      group_value.add_user(user)

      expect { group_value.add_user(user) }
        .not_to change { UserIndividualGroupValue.where(individual_group_value: group_value).count }
    end

    it "does not write the record when there is no stored address to clear" do
      user = create(:user)

      expect { group_value.add_user(user) }.not_to change { group_value.reload.updated_at }
    end

    it "drops a stored address once that person has an account" do
      group_value.add_email("spaeter@example.org")
      user = create(:user, email: "spaeter@example.org")

      group_value.add_user(user)

      expect(group_value.reload.auto_join_emails).to be_empty
    end
  end

  describe "#stored_email?" do
    it "recognises a stored address and an existing member" do
      group_value.add_email("gespeichert@example.org")
      member = create(:user, email: "mitglied@example.org")
      group_value.add_user(member)

      expect(group_value.stored_email?("Gespeichert@example.org")).to be true
      expect(group_value.stored_email?("mitglied@example.org")).to be true
      expect(group_value.stored_email?("fremd@example.org")).to be false
    end
  end

  describe "joining on registration" do
    it "adds a person who registers with a stored address" do
      group_value.add_email("wartet@example.org")

      user = create(:user, email: "wartet@example.org")

      expect(user.individual_group_values).to include(group_value)
    end

    it "does not add them once the address has been removed" do
      group_value.add_email("entfernt@example.org")
      group_value.remove_auto_join_email("entfernt@example.org")

      user = create(:user, email: "entfernt@example.org")

      expect(user.individual_group_values).not_to include(group_value)
    end
  end

  describe "parity with the CSV import" do
    it "stores an address the same way both paths do" do
      csv_value = create(:individual_group_value)
      path = Rails.root.join("tmp", "igv_spec.csv")
      File.write(path, "email\nparitaet@example.org\n")

      csv_value.add_from_csv(path.to_s)
      group_value.add_email("paritaet@example.org")

      expect(group_value.reload.auto_join_emails).to eq(csv_value.reload.auto_join_emails)
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end
end
