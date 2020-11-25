section "Creating DEMO Users" do
  User.create!(email: "verified@consul.dev",
               password: "12345678",
               username: "verified",
               gender: "male",
               date_of_birth: 34.years.ago,
               verified_at: 1.month.ago,
               confirmed_at: 1.month.ago,
               document_number: "12345678A",
               document_type: "1",
               residence_verified_at: 1.month.ago,
               confirmed_phone: "987654321",
               level_two_verified_at: 1.month.ago,
               email_on_comment: false,
               email_on_comment_reply: false,
               terms_of_service: "1")
end
