require "rails_helper"

describe ProjektPhase do
  describe "#customizable_email_template_groups" do
    context "with a phase that does not override the groups" do
      let(:projekt_phase) { ProjektPhase::ProposalPhase.new(projekt: build(:projekt)) }

      it "returns a single group with a nil key wrapping the flat email templates" do
        groups = projekt_phase.customizable_email_template_groups

        expect(groups.size).to eq(1)
        expect(groups.first[:key]).to be_nil
        expect(groups.first[:templates].size).to eq(projekt_phase.customizable_email_templates.size)
      end

      it "exposes each template as a hash with mailer_class, mailer_action and recipient_type" do
        template = projekt_phase.customizable_email_template_groups.first[:templates].first

        expect(template.keys).to match_array([:mailer_class, :mailer_action, :recipient_type])
        expect(template[:recipient_type]).to be_nil
      end
    end

    context "for ProjektPhase::BudgetPhase" do
      let(:projekt_phase) { ProjektPhase::BudgetPhase.new(projekt: build(:projekt)) }

      it "returns four lifecycle groups" do
        groups = projekt_phase.customizable_email_template_groups

        expect(groups.size).to eq(4)
        expect(groups.map { |g| g[:key] }).to eq(%w[submission feasibility preselection selection])
      end

      it "exposes eight templates in total across the groups" do
        templates = projekt_phase.customizable_email_template_groups.flat_map { |g| g[:templates] }

        expect(templates.size).to eq(8)
      end

      it "keeps customizable_email_templates in sync as a flat list" do
        flat_from_groups = projekt_phase.customizable_email_template_groups
          .flat_map { |g| g[:templates].map { |t| [t[:mailer_class], t[:mailer_action]] } }

        expect(projekt_phase.customizable_email_templates).to eq(flat_from_groups)
      end

      it "tags each template with a recipient_type" do
        templates = projekt_phase.customizable_email_template_groups.flat_map { |g| g[:templates] }

        expect(templates.map { |t| t[:recipient_type] }).to all(be_present)
      end
    end
  end
end
