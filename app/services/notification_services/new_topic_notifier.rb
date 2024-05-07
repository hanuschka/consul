module NotificationServices
  class NewTopicNotifier < ApplicationService
    def initialize(topic_id)
      @topic = Topic.find(topic_id)
      @community = @topic.community
    end

    def call
      users_to_notify_ids.each do |user_id|
        NotificationServiceMailer.new_topic(user_id, @community.id, @topic.id).deliver_later
      end
    end

    private

      def users_to_notify_ids
        administrator_ids = User.joins(:administrator).where(adm_email_on_new_topic: true).ids
        projekt_manager_ids = User.joins(projekt_manager: :projekts).where(adm_email_on_new_topic: true)
          .where(projekt_managers: { projekts: { id: @community.proposal&.projekt_phase&.projekt&.id }}).ids

        [administrator_ids, projekt_manager_ids].flatten.uniq
      end
  end
end
