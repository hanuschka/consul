namespace :email_templates do
  desc "Test all customizable email templates - sends default and customized version of each"
  task test_all: :environment do
    user = User.first
    abort "No user found" unless user

    puts "Testing with user: #{user.username} (#{user.email})"
    puts "Emails will appear at /letter_opener"
    puts "=" * 60

    # Phase-specific templates - need real records
    investment = Budget::Investment.last
    proposal = Proposal.first
    poll = Poll.first
    comment = Comment.first
    reply_comment = Comment.where.not(ancestry: nil).first
    dm = DirectMessage.first
    pra = PendingRoleAssignment.first
    igv = IndividualGroupValue.first
    question_phase = ProjektPhase::QuestionPhase.first
    argument_phase = ProjektPhase::ArgumentPhase.first
    notification_phase = ProjektPhase::ProjektNotificationPhase.first
    event_phase = ProjektPhase::EventPhase.first
    milestone_phase = ProjektPhase::MilestonePhase.first
    livestream_phase = ProjektPhase::LivestreamPhase.first

    # Define all testable emails
    tests = []

    # Mailer - phase-specific
    if proposal
      tests << {
        name: "Mailer#proposal_created",
        phase: proposal.projekt_phase,
        call: -> { Mailer.proposal_created(proposal).deliver_now }
      }
    end

    if investment
      budget_phase = investment.budget&.projekt_phase
      tests << {
        name: "Mailer#budget_investment_created",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_created(investment).deliver_now }
      }
      tests << {
        name: "Mailer#budget_investment_feasible",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_feasible(investment).deliver_now }
      }
      tests << {
        name: "Mailer#budget_investment_unfeasible",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_unfeasible(investment).deliver_now }
      }
      tests << {
        name: "Mailer#budget_investment_selected",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_selected(investment).deliver_now }
      }
      tests << {
        name: "Mailer#budget_investment_unselected",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_unselected(investment).deliver_now }
      }
      tests << {
        name: "Mailer#budget_investment_preselected",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_preselected(investment).deliver_now }
      }
      tests << {
        name: "Mailer#budget_investment_not_preselected",
        phase: budget_phase,
        call: -> { Mailer.budget_investment_not_preselected(investment).deliver_now }
      }
    end

    # Mailer - global
    if comment
      tests << {
        name: "Mailer#comment",
        phase: nil,
        call: -> { Mailer.comment(comment).deliver_now }
      }
    end

    if reply_comment
      tests << {
        name: "Mailer#reply",
        phase: nil,
        call: -> { Mailer.reply(reply_comment).deliver_now }
      }
    end

    if dm
      tests << {
        name: "Mailer#direct_message_for_receiver",
        phase: nil,
        call: -> { Mailer.direct_message_for_receiver(dm).deliver_now }
      }
    end

    tests << {
      name: "Mailer#resource_hidden",
      phase: nil,
      call: -> { Mailer.resource_hidden(proposal || comment).deliver_now }
    } if proposal || comment

    tests << { name: "Mailer#already_confirmed", phase: nil, call: -> { Mailer.already_confirmed(user).deliver_now } }
    tests << { name: "Mailer#manual_verification_confirmation", phase: nil, call: -> { Mailer.manual_verification_confirmation(user).deliver_now } }
    tests << { name: "Mailer#newsletter_subscription_for_existing_user", phase: nil, call: -> { Mailer.newsletter_subscription_for_existing_user(user).deliver_now } }
    tests << { name: "Mailer#user_invite", phase: nil, call: -> { Mailer.user_invite(user.email).deliver_now } }

    if pra
      tests << { name: "Mailer#pending_role_invite", phase: nil, call: -> { Mailer.pending_role_invite(pra).deliver_now } }
    end

    tests << { name: "Mailer#csv_download_ready", phase: nil, call: -> { Mailer.csv_download_ready(user, "https://example.com/download/test.csv").deliver_now } }

    if igv
      tests << { name: "Mailer#individual_group_value_users_added", phase: nil, call: -> { Mailer.individual_group_value_users_added(user.id, igv.id).deliver_now } }
    end

    tests << { name: "Mailer#existing_stamp_notify_existing_user", phase: nil, call: -> { Mailer.existing_stamp_notify_existing_user(user).deliver_now } }
    tests << { name: "Mailer#existing_stamp_notify_new_user", phase: nil, call: -> { Mailer.existing_stamp_notify_new_user(user.email).deliver_now } }
    tests << { name: "Mailer#user_verification_failed", phase: nil, call: -> { Mailer.user_verification_failed(user).deliver_now } }

    # NotificationServiceMailer - phase-specific
    if proposal
      tests << {
        name: "NotificationServiceMailer#new_proposal",
        phase: proposal.projekt_phase,
        call: -> { NotificationServiceMailer.new_proposal(user.id, proposal.id).deliver_now }
      }
    end

    if poll
      tests << {
        name: "NotificationServiceMailer#new_poll",
        phase: poll.projekt_phase,
        call: -> { NotificationServiceMailer.new_poll(user.id, poll.id).deliver_now }
      }
    end

    phase_comment = Comment.all.find { |c| c.commentable.is_a?(ProjektPhase) }
    if phase_comment
      tests << {
        name: "NotificationServiceMailer#new_comment",
        phase: phase_comment.commentable,
        call: -> { NotificationServiceMailer.new_comment(user.id, phase_comment.id).deliver_now }
      }
    end

    if question_phase
      tests << {
        name: "NotificationServiceMailer#projekt_questions",
        phase: question_phase,
        call: -> { NotificationServiceMailer.projekt_questions(user.id, question_phase.id).deliver_now }
      }
    end

    if argument_phase
      tests << {
        name: "NotificationServiceMailer#projekt_arguments",
        phase: argument_phase,
        call: -> { NotificationServiceMailer.projekt_arguments(user.id, argument_phase.id).deliver_now }
      }
    end

    if notification_phase&.projekt_notifications&.any?
      tests << {
        name: "NotificationServiceMailer#new_projekt_notification",
        phase: notification_phase,
        call: -> { NotificationServiceMailer.new_projekt_notification(user.id, notification_phase.projekt_notifications.first.id).deliver_now }
      }
    end

    if event_phase&.projekt_events&.any?
      tests << {
        name: "NotificationServiceMailer#new_projekt_event",
        phase: event_phase,
        call: -> { NotificationServiceMailer.new_projekt_event(user.id, event_phase.projekt_events.first.id).deliver_now }
      }
    end

    if milestone_phase&.milestones&.any?
      tests << {
        name: "NotificationServiceMailer#new_projekt_milestone",
        phase: milestone_phase,
        call: -> { NotificationServiceMailer.new_projekt_milestone(user.id, milestone_phase.milestones.first.id).deliver_now }
      }
    end

    if livestream_phase&.projekt_livestreams&.any?
      tests << {
        name: "NotificationServiceMailer#new_projekt_livestream",
        phase: livestream_phase,
        call: -> { NotificationServiceMailer.new_projekt_livestream(user.id, livestream_phase.projekt_livestreams.first.id).deliver_now }
      }
    end

    if investment
      tests << {
        name: "NotificationServiceMailer#new_budget_investment",
        phase: investment.budget&.projekt_phase,
        call: -> { NotificationServiceMailer.new_budget_investment(user.id, investment.id).deliver_now }
      }
    end

    # NotificationServiceMailer - global
    tests << { name: "NotificationServiceMailer#user_reverification_failed", phase: nil, call: -> { NotificationServiceMailer.user_reverification_failed(user.id).deliver_now } }
    tests << { name: "NotificationServiceMailer#user_reverification_succeeded", phase: nil, call: -> { NotificationServiceMailer.user_reverification_succeeded(user.id).deliver_now } }

    # Run all tests
    passed = 0
    failed = 0

    tests.each_with_index do |test, index|
      mailer_class, mailer_action = test[:name].split("#")
      default_ok = false
      custom_ok = false

      puts "\n[#{index + 1}/#{tests.size}] #{test[:name]}"
      puts "-" * 40
      puts "  Mailer:  #{mailer_class}"
      puts "  Method:  #{mailer_action}"
      puts "  Phase:   #{test[:phase]&.class&.name || 'global'}"

      # Phase 1: Send with default template
      print "  DEFAULT: "
      begin
        test[:call].call
        puts "OK"
        default_ok = true
        passed += 1
      rescue => e
        puts "FAILED: #{e.message}"
        failed += 1
      end

      # Phase 2: Create a customized template and send again
      print "  CUSTOM:  "
      begin
        template = SiteCustomization::EmailTemplate.find_or_create_by!(
          projekt_phase: test[:phase],
          mailer_class: mailer_class,
          mailer_action: mailer_action,
          locale: I18n.locale
        )

        original_subject = template.subject
        original_body = template.body

        variables = template.registered_variables
        var_text = variables.map { |v| "{{ #{v} }}" }.join(", ")

        template.update!(
          subject: "[TEST CUSTOM] #{test[:name]} - #{var_text}",
          body: "<p>Customized template for <strong>#{test[:name]}</strong></p><p>Variables: #{var_text}</p>"
        )

        test[:call].call
        puts "OK"
        custom_ok = true
        passed += 1

        # Restore original
        template.update!(subject: original_subject, body: original_body)
      rescue => e
        puts "FAILED: #{e.message}"
        failed += 1
      end

      status = [default_ok ? "DEFAULT OK" : "DEFAULT FAILED", custom_ok ? "CUSTOM OK" : "CUSTOM FAILED"].join(" | ")
      puts "\n  Result: #{status}"
      puts "  Check /letter_opener for the two emails above."
      print "  Press ENTER to continue (or 'q' to quit)... "
      input = $stdin.gets&.strip
      break if input == "q"
    end

    puts "\n" + "=" * 60
    puts "Results: #{passed} passed, #{failed} failed"
    puts "Check /letter_opener for all sent emails"
  end
end
