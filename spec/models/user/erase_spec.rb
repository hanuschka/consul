require "rails_helper"

describe User, "#erase" do
  let(:personal_data) do
    {
      first_name: "Lena", last_name: "Vogt", date_of_birth: Date.new(1990, 5, 1), gender: "female",
      street_name: "Marienplatz", street_number: "1", plz: 80331, city_name: "München",
      document_type: "1", document_number: "12345678Z", document_last_digits: "678Z",
      current_sign_in_ip: "203.0.113.7", last_sign_in_ip: "203.0.113.8", guest_user_agent: "Firefox",
      oauth_email: "lena@example.org", company_name: "Vogt GmbH", official_position: "Stadträtin"
    }
  end
  let(:user) { create(:user, **personal_data) }

  it "removes the personal data of the account" do
    user.erase("Auf Wunsch gelöscht")

    user.reload
    expect(user).to be_erased
    expect(user.email).to be_nil
    expect(user.username).to be_nil
    (personal_data.keys - [:document_number]).each do |attribute|
      expect(user.public_send(attribute)).to be_nil, "#{attribute} is still stored"
    end
  end

  it "keeps no readable unique stamp or document number" do
    user.update_columns(unique_stamp: user.prepare_unique_stamp)

    user.erase

    user.reload
    expect(user.unique_stamp).to eq User.erased_identifier("lena_vogt_1990_05_01_80331")
    expect(user.document_number).to eq User.erased_document_identifier("12345678Z", "1")
    expect([user.unique_stamp, user.document_number].join).not_to include("lena", "12345678Z")
  end

  it "keeps comments, shown as written by a deleted user" do
    comment = create(:comment, user: user, body: "Bitte mehr Bänke")

    user.erase

    expect(comment.reload.body).to eq "Bitte mehr Bänke"
    expect(comment.user).to be_erased
  end

  it "keeps a poll vote in the result without the voter's document data" do
    poll = create(:poll)
    voter = Poll::Voter.create!(poll: poll, user: user, origin: "web")
    voter.update_columns(document_number: "12345678Z", gender: "female")

    user.erase

    expect(Poll::Voter.where(poll: poll).count).to eq 1
    expect(voter.reload.document_number).to be_nil
    expect(voter.gender).to be_nil
  end

  it "removes personal data stored with the account elsewhere" do
    FailedCensusCall.create!(user: user, document_number: "12345678Z", document_type: "1")
    registration = ProjektEventRegistration.create!(
      projekt_event: create(:projekt_event), user: user,
      first_name: "Lena", last_name: "Vogt", email: "lena@example.org"
    )
    User.connection.execute(
      "INSERT INTO visits (id, user_id, ip, user_agent) " \
      "VALUES (gen_random_uuid(), #{user.id}, '203.0.113.7', 'Firefox')"
    )

    user.erase

    expect(FailedCensusCall.where(user_id: user.id)).to be_empty
    expect(registration.reload.attributes.values_at("first_name", "last_name", "email")).to all(be_nil)
    expect(User.connection.select_value("SELECT COUNT(*) FROM visits WHERE user_id = #{user.id}")).to eq 0
  end

  it "removes contact data from the account's form answers and keeps the other answers" do
    formular = Formular.create!(projekt_phase: create(:projekt_phase))
    email_field = formular.formular_fields.create!(name: "E-Mail", kind: "email")
    text_field = formular.formular_fields.create!(name: "Idee", kind: "string")
    answer = FormularAnswer.create!(
      formular: formular, submitter: user, original_submitter_email: "lena@example.org",
      answers: { email_field.reload.key => "lena@example.org", text_field.reload.key => "Mehr Bänke" }
    )
    letter = FormularFollowUpLetter.create!(formular: formular, subject: "Danke", body: "Danke")
    FormularFollowUpLetterRecipient.create!(formular_follow_up_letter: letter, formular_answer: answer)

    user.erase

    expect(answer.reload.original_submitter_email).to be_nil
    expect(answer.answers).to eq(text_field.key => "Mehr Bänke")
    expect(FormularFollowUpLetterRecipient.where(formular_answer: answer)).to be_empty
  end

  it "removes the IP address from changes the account made and its API access" do
    audit = Audit.create!(auditable: create(:comment), user: user, action: "update",
                          remote_address: "203.0.113.7")
    GraphqlUser.create!(user: user)

    user.erase

    expect(audit.reload.remote_address).to be_nil
    expect(GraphqlUser.where(user: user)).to be_empty
  end

  it "hands the old votes to the same person when they register again" do
    comment = create(:comment)
    user.update_columns(unique_stamp: user.prepare_unique_stamp)
    Vote.create!(votable: comment, voter: user, vote_flag: true)
    user.erase

    returning_user = create(:user, unique_stamp: "lena_vogt_1990_05_01_80331")

    expect(Vote.where(voter: returning_user).count).to eq 1
    expect(user.reload.unique_stamp).to be_nil
  end

  it "hands the old votes to the same person when they verify the same document again" do
    comment = create(:comment)
    Vote.create!(votable: comment, voter: user, vote_flag: true)
    user.erase

    returning_user = create(:user)
    returning_user.take_votes_if_erased_document("12345678Z", "1")

    expect(Vote.where(voter: returning_user).count).to eq 1
    expect(user.reload.document_number).to be_nil
  end
end
