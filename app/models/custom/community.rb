require_dependency Rails.root.join("app", "models", "community").to_s

class Community
  MAX_TOPICS = 4

  PREDEFINED_TOPICS = [
    {title: I18n.t("topics_predefined.topic1"), description: I18n.t("topics_predefined.description1")},
    {title: I18n.t("topics_predefined.topic2"), description: I18n.t("topics_predefined.description2")},
    {title: I18n.t("topics_predefined.topic3"), description: I18n.t("topics_predefined.description3")},
    {title: I18n.t("topics_predefined.topic4"), description: I18n.t("topics_predefined.description4")}
  ]

  ADMIN_USER_ID = 3

  after_create :init_topics

  def init_topics
    # user = (proposal || investment).author

    PREDEFINED_TOPICS.each do |t|
      topics.create(title: t[:title], description: t[:description], author: User.administrators.first)
    end
  end
end