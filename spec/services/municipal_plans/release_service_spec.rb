require "rails_helper"

describe MunicipalPlans::ReleaseService do
  let(:officer) { create(:municipal_plan_officer) }
  let(:district) { create(:registered_address_district) }
  let(:topic) { create(:municipal_plan_topic) }

  describe "the first publication" do
    let(:plan) { create(:municipal_plan, responsible: officer) }

    it "publishes the Entwurf itself and starts the 1 series" do
      plan.update!(submitted_at: Time.current)

      MunicipalPlans::ReleaseService.call(plan)

      expect(plan.reload).to be_published
      expect(plan.version).to eq("1.0")
      expect(plan.submitted_at).to be_nil
    end
  end

  describe "a later change" do
    let(:plan) do
      create(:municipal_plan, :published, responsible: officer,
                                          short_description: "Alte Fassung")
    end
    let(:copy) { MunicipalPlans::WorkingCopyService.call(plan) }

    before { plan.update_columns(version: "1.0", content_updated_at: Date.current - 10.days) }

    it "moves the new text onto the released Vorhaben" do
      copy.update!(short_description: "Neue Fassung", submitted_at: Time.current)

      MunicipalPlans::ReleaseService.call(copy)

      expect(plan.reload.short_description).to eq("Neue Fassung")
    end

    it "advances Versionsnummer and Aktualisierungsdatum" do
      copy.update!(short_description: "Neue Fassung", submitted_at: Time.current)

      MunicipalPlans::ReleaseService.call(copy)

      expect(plan.reload.version).to eq("1.1")
      expect(plan.content_updated_at).to eq(Date.current)
    end

    it "keeps the id of the released Vorhaben and removes the copy" do
      copy.update!(short_description: "Neue Fassung", submitted_at: Time.current)
      copy_id = copy.id

      released = MunicipalPlans::ReleaseService.call(copy)

      expect(released.id).to eq(plan.id)
      expect(MunicipalPlan.where(id: copy_id)).to be_empty
      expect(plan.reload.working_copy).to be_nil
    end

    it "advances the version when only the Ortsteile changed" do
      copy.district_ids = [district.id]
      copy.update!(submitted_at: Time.current)

      MunicipalPlans::ReleaseService.call(copy)

      expect(plan.reload.district_ids).to match_array([district.id])
      expect(plan.version).to eq("1.1")
      expect(plan.content_updated_at).to eq(Date.current)
    end

    it "carries Themen, Links and the Kartenposition over" do
      copy.topic_ids = [topic.id]
      copy.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)
      copy.map_location.update!(latitude: 50.9, longitude: 11.6)
      copy.update!(submitted_at: Time.current)

      MunicipalPlans::ReleaseService.call(copy)

      expect(plan.reload.topic_ids).to match_array([topic.id])
      expect(plan.links.map(&:title)).to eq(["Rahmenplan"])
      expect(plan.map_location.latitude).to eq(50.9)
    end

    it "keeps an archived Vorhaben archived" do
      plan.update!(status: "archived")
      copy.update!(short_description: "Neue Fassung", submitted_at: Time.current)

      MunicipalPlans::ReleaseService.call(copy)

      expect(plan.reload.status).to eq("archived")
      expect(plan.short_description).to eq("Neue Fassung")
      expect(plan.version).to eq("1.1")
    end

    it "keeps an Archivdatum set on the released Vorhaben while the copy was open" do
      plan.update!(archive_on: Date.current + 30.days)
      copy.update!(short_description: "Neue Fassung", submitted_at: Time.current)
      plan.update!(archive_on: Date.current + 60.days)

      MunicipalPlans::ReleaseService.call(copy)

      expect(plan.reload.archive_on).to eq(Date.current + 60.days)
    end

    it "leaves the released text alone until it is released" do
      copy.update!(short_description: "Neue Fassung", submitted_at: Time.current)

      expect(plan.reload.short_description).to eq("Alte Fassung")
      expect(plan.content_updated_at).to eq(Date.current - 10.days)
    end
  end

  describe "the change log" do
    let(:admin) { create(:administrator).user }

    def audited_fields(plan)
      plan.own_and_associated_audits.where(action: "update").flat_map do |audit|
        audit.audited_changes.keys.map { |field| [field, audit.user] }
      end
    end

    it "records the first publication as a release by the administrator" do
      plan = create(:municipal_plan, responsible: officer)
      plan.update!(submitted_at: Time.current)

      Audited.audit_class.as_user(admin) { MunicipalPlans::ReleaseService.call(plan) }

      expect(audited_fields(plan.reload)).to include(["released_at", admin])
      expect(plan.released_at).to be_present
    end

    describe "a later change" do
      let!(:plan) do
        create(:municipal_plan, :published, responsible: officer, short_description: "Alte Fassung",
                                            internal_notes: "Alt")
      end
      let!(:copy) { MunicipalPlans::WorkingCopyService.call(plan) }

      before do
        Audited.audit_class.as_user(officer.user) do
          copy.update!(short_description: "Neue Fassung", internal_notes: "Neu")
          copy.update!(submitted_at: Time.current)
        end

        Audited.audit_class.as_user(admin) { MunicipalPlans::ReleaseService.call(copy) }
      end

      it "names the author of each change, once" do
        fields = audited_fields(plan.reload)

        expect(fields.count(["short_description", officer.user])).to eq(1)
        expect(fields.count(["internal_notes", officer.user])).to eq(1)
        expect(fields.map(&:first).count("short_description")).to eq(1)
        expect(fields.map(&:first).count("internal_notes")).to eq(1)
      end

      it "adds one release entry by the administrator" do
        release_audits = plan.reload.own_and_associated_audits.where(action: "update")
                             .select { |audit| audit.audited_changes.key?("released_at") }

        expect(release_audits.size).to eq(1)
        expect(release_audits.first.user).to eq(admin)
        expect(release_audits.first.audited_changes.keys).to eq(["released_at"])
      end

      it "leaves the copy's creation and removal out of the log" do
        expect(plan.reload.own_and_associated_audits.where(action: %w[create destroy]).map(&:associated_id)
                   .compact.uniq).to eq([plan.id])
        expect(plan.own_and_associated_audits.where(action: "create", auditable_type: "MunicipalPlan").count)
          .to eq(1)
      end
    end
  end
end
