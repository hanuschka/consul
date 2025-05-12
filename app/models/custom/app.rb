class App < ApplicatonRecord
  APP_CODENAMES = [
    VOICE_ASSISTANT = "voice_assistant"
  ]

  validates :codename, presence: true, inclusion: { in: APP_CODENAMES }
end
