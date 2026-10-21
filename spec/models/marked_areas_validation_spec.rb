require "rails_helper"

describe MarkedAreasValidation do
  def collection(*geometries)
    {
      "type" => "FeatureCollection",
      "features" => geometries.map { |geometry| { "type" => "Feature", "properties" => {}, "geometry" => geometry } }
    }
  end

  def point(lng, lat)
    { "type" => "Point", "coordinates" => [lng, lat] }
  end

  let(:area) do
    collection("type" => "Polygon",
               "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]])
  end
  let(:inside) { collection(point(7.1, 50.9)) }
  let(:outside) { collection(point(7.5, 50.9)) }
  let(:message) { I18n.t("activerecord.errors.messages.map_features_outside_marked_areas") }

  def place(record, features)
    record.map_location = build(:map_location, latitude: 50.9, longitude: 7.1, features: features)
    record
  end

  def restrict(phase)
    phase.settings.find_by!(key: "feature.form.restrict_map_features_to_marked_areas").update!(value: "active")
    phase.reload.map_location.update!(features: area)
    phase.reload
  end

  shared_examples "a resource restricted to the phase's marked areas" do
    it "accepts any location while the phase setting is off" do
      phase.reload.map_location.update!(features: area)

      expect(place(new_record, outside)).to be_valid
    end

    context "with the setting on and areas drawn" do
      before { restrict(phase) }

      it "accepts a location inside the areas" do
        expect(place(new_record, inside)).to be_valid
      end

      it "refuses a location outside the areas" do
        record = place(new_record, outside)

        expect(record).not_to be_valid
        expect(record.errors.full_messages).to include(message)
      end

      it "accepts an entry without a location" do
        expect(new_record).to be_valid
      end

      it "skips the check when asked to" do
        record = place(new_record, outside)
        record.skip_marked_areas_check = true

        expect(record).to be_valid
      end

      it "fails open and reports to Sentry when the areas cannot be tested" do
        allow_any_instance_of(MapBoundary).to receive(:usable?).and_return(false)
        expect(Sentry).to receive(:capture_message).with(/GEOS is unavailable/, hash_including(level: :warning))

        expect(place(new_record, outside)).to be_valid
      end
    end

    context "with an entry placed before the setting was switched on" do
      let!(:record) { place(new_record, outside).tap(&:save!) }

      before { restrict(phase) }

      it "can still be edited while its location stays where it is" do
        record.reload

        expect(record).to be_valid
      end

      it "is refused when its location is moved, but still outside" do
        record.reload.map_location.features = collection(point(7.6, 50.9))

        expect(record).not_to be_valid
      end

      it "is accepted when its location is moved inside" do
        record.reload.map_location.features = inside

        expect(record).to be_valid
      end
    end
  end

  describe Proposal do
    let(:phase) { create(:proposal_phase) }
    let(:new_record) { build(:proposal, projekt_phase: phase) }

    it_behaves_like "a resource restricted to the phase's marked areas"
  end

  describe Budget::Investment do
    let(:phase) { create(:budget_phase) }
    let(:budget) { phase.reload.budget }
    let(:new_record) { build(:budget_investment, budget: budget, heading: budget.heading) }

    it_behaves_like "a resource restricted to the phase's marked areas"
  end

  describe ProjektPointOfInterestPin do
    let(:phase) { create(:point_of_interest_phase) }
    let(:new_record) { ProjektPointOfInterestPin.new(projekt_phase: phase, author: create(:user)) }

    it_behaves_like "a resource restricted to the phase's marked areas"
  end
end
