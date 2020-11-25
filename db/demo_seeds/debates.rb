section "Creating DEMO Debates" do

  admin = User.find_by(email: "admin@consul.dev")
  verified = User.find_by(email: "verified@consul.dev")

  debate = Debate.create!(author: admin,
                          title: "#YouAsk: Julio Airroa, city council expert on environmental pollution",
                          description: "<p>Glad to answer your questions about city pollution.</p>\r\n\r\n<p>\r\nI introduce myself first. I have a PhD in Industrial Engineering from the Polytechnic University. Professor of Environmental Engineering at the School of Industrial Engineers of the Polytechnic University. Deputy Director of Academic Planning at the School of Industrial Engineers. National representative in the Geneva Convention working group on modelling and integral assessment of air quality. Co-author of 28 books and 40 articles in international journals. Participant in more than forty national and international congresses or workshops, in 33 competitive projects and more than 30 projects with private organizations.</p>\r\n\r\n<p>\r\nYou can leave your questions about the environment, pollution or air quality.</p>\r\n\r\n<p>\r\nOn Wednesday at 18:00 h. I will come in to answer them.</p>\r\n\r\n<p></p>\r\n\r\n<p></p>\r\n",
                          tag_list: "youask,pollution,environment",
                          terms_of_service: "1",
                          created_at: 1.month.ago)

  up_voters = users.sample(6)
  up_voters.each do |voter|
    debate.vote_by(voter: voter, vote: true)
  end

  debate = Debate.create!(author: admin,
                          title: "Would it be okay if the city surrounded itself with a green belt by the highway?",
                          description: "<p>One of the most powerful CO2 sinks and pollution filter are forests and trees. Surrounding ourselves with autochthonous vegetation by taking advantage of the margins and slopes of the ring roads would be a good way to counteract the emissions produced on these roads. It would give more environmental quality to the city and mitigate heat waves, landscape restoration, among other benefits.</p>\r\n\r\n<p>However, there are people who think that this is too expensive and it would be better to look for other ways to reduce pollution. What do you think?</p>\r\n\r\n<p></p>\r\n",
                          tag_list: "environment,transport,trees",
                          terms_of_service: "1",
                          created_at: 1.week.ago)

  debate = Debate.create!(author: admin,
                          title: "Public sources, benches and shadows.",
                          description: "<p>The streets and squares of the city have become hard: only cement, without fountains, benches or shadows. It is supposed to facilitate maintenance, but in reality the only important impact is the increase in consumption in large establishments by seeking refuge in them and the use of public spaces with terraces, promotional events, etc...</p>\r\n\r\n<p>\r\nHow could we solve this question? Do you think it benefits the city?</p>\r\n\r\n<p>\r\nFor example, it occurs to me that it would be good to create a network of drinking water fountains and install more benches and shadows in all the streets and squares. This would stimulate sport, pedestrianism and social exchange.</p>\r\n\r\n<p>\r\nWhat do you think?</p>\r\n",
                          tag_list: "urbanism,fountains,benches,squares",
                          terms_of_service: "1",
                          created_at: 1.day.ago)

  debate = Debate.create!(author: verified,
                          title: "Rental prices",
                          description: "<p>Over the last couple of years, the weight of rents has increased dramatically, although the number of tourists walking around the city has also increased.</p>\r\n\r\n<p>It is sometimes proposed that not only is there a correlation, but that the type of tourist rental is the root cause of the former. But it is difficult to find data to prove the claim.</p>\r\n\r\n<p>Does anyone have sufficiently comprehensive sources of information on this issue to resolve it?</p>\r\n\r\n<p></p>\r\n",
                          tag_list: "urbanism,housing,regulation,price",
                          terms_of_service: "1",
                          created_at: 1.hour.ago)

  debate = Debate.create!(author: verified,
                          title: "Metro at night (on weekends). Is it positive?",
                          description: "<p>This is a debate that has been going on for a long time and it is the possibility of opening the metro on weekends at night. It would be important to know if it is a positive measure or too expensive for what it reports to the city.</p>\r\n\r\n<p>We do not need too high a frequency, but we do not need more than 20 minutes, because if we had to change trains, it would drive many people back. It would be interesting,</p>\r\n\r\n<p>if someone knows a little more about the subject, to know the cons that this would have, because I believe that currently, there is no metro in the world that is open at night, so I do not think it is an easy task. </p>\r\n",
                          tag_list: "urbanism,transport,metro",
                          terms_of_service: "1",
                          created_at: 1.minute.ago)

  debate.update(updated_at: 1.second.ago)
end
