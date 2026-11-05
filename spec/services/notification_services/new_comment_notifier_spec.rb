require "rails_helper"

describe NotificationServices::NewCommentNotifier do
  include ActiveJob::TestHelper

  let(:admin) { create(:administrator).user }

  before { admin.update!(adm_email_on_new_comment: true) }

  it "sends the comment phase email for comments in a comment phase" do
    comment = create(:comment, commentable: create(:projekt_phase))

    expect { described_class.call(comment.id) }
      .to have_enqueued_mail(NotificationServiceMailer, :new_comment).with(admin.id, comment.id)
  end

  it "sends the contribution email for comments on a contribution" do
    comment = create(:comment, commentable: create(:proposal))

    expect { described_class.call(comment.id) }
      .to have_enqueued_mail(NotificationServiceMailer, :new_contribution_comment).with(admin.id, comment.id)
  end
end
