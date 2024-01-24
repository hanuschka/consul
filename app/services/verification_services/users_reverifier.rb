module VerificationServices
  class UsersReverifier < ApplicationService
    def initialize
      @users = User.to_reverify
    end

    def call
      # @users.each do |user|
      #   user.delay(run_at: (Time.zone.now + 5.minutes)).reverify!
      #   sleep 1
      # end
    end
  end
end
