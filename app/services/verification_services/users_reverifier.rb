module VerificationServices
  class UsersReverifier < ApplicationService
    def initialize
      @users = User.to_reverify
    end

    def call
      return if Setting["feature.melderegister"].blank?

      @users.each do |user|
        user.delay(run_at: (Time.zone.now + 5.minutes)).reverify!
        sleep 1
      end
    end
  end
end
