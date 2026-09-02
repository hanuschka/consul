module ApiRecordHelper
  def create_projekt_phase(type)
    projekt = Projekt.create!(name: "Projekt #{SecureRandom.hex(4)}")

    projekt.projekt_phases.create!(type: type, active: true)
  end

  def create_admin_user(email: "admin_spec_#{SecureRandom.hex(4)}@example.com")
    existing_administrator = User.administrators.first
    return existing_administrator if existing_administrator

    user = User.create!(
      username: "admin_user_#{SecureRandom.hex(4)}",
      email: email,
      password: SecureRandom.hex(32),
      confirmed_at: Time.current,
      terms_data_storage: '1',
      terms_data_protection: '1',
      terms_general: '1',
      skip_password_validation: true
    )
    Administrator.create!(user: user)

    user
  end

  def create_poll_question(poll, title:, author: nil)
    poll.questions.create!(
      title: title,
      author: author || create_admin_user,
      votation_type: VotationType.new(vote_type: :unique)
    )
  end
end
