module NotificationServices
  class NewTopicNotifier < ApplicationService
    def initialize(topic_id)
      @topic = Topic.find(topic_id)
      @community = @topic.community
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_topic(user.id, @community.id, @topic.id).deliver_later
        Notification.add(user, @topic)
        Activity.log(user, "email", @topic)
      end
    end

    private

      def users_to_notify
        [administrators, projekt_managers]
          .flatten.uniq(&:id)
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_topic: true).to_a
      end

      def projekt_managers
        User.joins(projekt_manager: :projekts).where(adm_email_on_new_topic: true)
          .where(projekt_managers: { projekts: { id: @community.proposal&.projekt_phase&.projekt&.id }}).to_a
      end
  end
end
