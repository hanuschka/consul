module NotificationServices
  class CustomMailNotifier < ApplicationService
    def initialize(user_ids, title, body)
      @user_ids = user_ids
      @title = title
      @body = body
    end

    def call
      return if users_to_notify.empty?

      users_to_notify.each do |user|
        Mailer.custom_mail(user, @title, @body).deliver_later
      end

      puts "E-Mails wurden versendet an: #{users_to_notify.map(&:id).join(", ")}"
    end

    private

      def users_to_notify
        if @user_ids.is_a?(Array) && @user_ids.all? { |id| id.is_a?(Integer) }
          User.actual.where(id: @user_ids)
        else
          puts "Bitte geben Sie als erstes Argument ein Array von Benutzer-IDs an"
          []
        end
      end
  end
end
