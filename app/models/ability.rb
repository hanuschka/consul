class Ability
  include CanCan::Ability

  # preview_gid is the record named by a signed link from the on-behalf-of account mail, if the
  # request carried one. See ApplicationController#on_behalf_of_preview_gid.
  def initialize(user, preview_gid: nil)
    if user # logged-in users
      can :use, :voice_assistant

      merge Abilities::Valuator.new(user) if user.valuator?
      merge Abilities::ProjektManager.new(user) if user.projekt_manager? && !user.administrator?
      merge Abilities::DeficiencyReportManager.new(user) if user.deficiency_report_manager?
      merge Abilities::IdeaManager.new(user) if user.idea_manager?

      if user.administrator?
        merge Abilities::Administrator.new(user)
      elsif user.deficiency_report_officer?
        merge Abilities::DeficiencyReports::Officer.new(user)
      elsif user.moderator?
        merge Abilities::Moderator.new(user)
      elsif user.manager?
        merge Abilities::Manager.new(user)
      elsif user.sdg_manager?
        merge Abilities::SDG::Manager.new(user)
      elsif user.guest?
        merge Abilities::Everyone.new(user)
      else
        merge Abilities::Common.new(user)
      end
    else
      merge Abilities::Everyone.new(user)
    end

    # Last, so the link only ever widens: in CanCan the rule defined latest wins, and a pass for one
    # record must not become the reason a rule that already applied stops applying.
    #
    # Two actions because the gates this has to get past are not all CanCan's. Idea and
    # DeficiencyReport gate :show on admin acceptance in Abilities::Everyone, so :show is what opens
    # those. Proposal gates acceptance in its own controller and is already :read-able to everyone,
    # so asking :show there would answer true for every pending proposal — :preview is granted by
    # nothing else, which lets that controller test for this token exactly.
    #
    # safe_constantize because a token outlives a rename: the gid is signed, so the class name came
    # from us, but it can still name a model that no longer exists by the time the mail is opened.
    if (previewed = GlobalID.parse(preview_gid))
      previewable = previewed.model_name.safe_constantize
      can [:show, :preview], previewable, id: previewed.model_id.to_i if previewable
    end

    alias_action :wizard_step, to: :read
  end
end
