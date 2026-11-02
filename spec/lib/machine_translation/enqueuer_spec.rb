require "rails_helper"

describe MachineTranslation::Enqueuer do
  let(:source) { MachineTranslation.source_locale }
  let(:foreign) { (MachineTranslation.translatable_locales - [source]).first }

  before do
    allow(Deepl).to receive(:configured?).and_return(true)
    allow_any_instance_of(RemoteTranslation).to receive(:enqueue_remote_translation)
  end

  describe "MachineTranslation.translatable_locales_from" do
    it "matches translatable_locales when the source is the default locale" do
      expect(MachineTranslation.translatable_locales_from(source))
        .to eq MachineTranslation.translatable_locales
    end

    it "offers the default locale as a target when the source is not the default" do
      expect(MachineTranslation.translatable_locales_from(foreign)).to include source
    end

    it "never offers the source itself as a target" do
      expect(MachineTranslation.translatable_locales_from(foreign)).not_to include foreign
    end
  end

  describe "a deficiency report's reporter answer" do
    it "is not enqueued for translation when it changes alone" do
      report = Globalize.with_locale(source) { create(:deficiency_report) }
      RemoteTranslation.where(remote_translatable: report).delete_all

      Globalize.with_locale(source) { report.update!(reporter_answer: "Persönliche Rückmeldung") }

      expect(RemoteTranslation.where(remote_translatable: report)).to be_empty
    end

    it "is never sent to the translation service" do
      report = Globalize.with_locale(source) do
        create(:deficiency_report, official_answer: "Öffentliche Antwort", reporter_answer: "Persönliche Rückmeldung")
      end
      remote_translation = RemoteTranslation.create!(remote_translatable: report, locale: foreign.to_s)
      sent = nil
      client = instance_double(Deepl::Client)
      allow(Deepl::Client).to receive(:new).and_return(client)
      allow(client).to receive(:translate) { |values, **| sent = values; values }

      RemoteTranslations::Caller.new(remote_translation, source_locale: source).call

      expect(sent).to include("Öffentliche Antwort")
      expect(sent).not_to include("Persönliche Rückmeldung")
    end
  end

  describe "enqueueing for a comment" do
    def enqueued_locales_for(comment)
      RemoteTranslation.where(remote_translatable: comment).pluck(:locale)
    end

    it "does not target the default locale for content authored in it" do
      comment = Globalize.with_locale(source) { create(:comment) }

      expect(enqueued_locales_for(comment)).not_to include source.to_s
    end

    it "targets the default locale for content authored in another language" do
      comment = Globalize.with_locale(foreign) { create(:comment) }

      expect(enqueued_locales_for(comment)).to include source.to_s
      expect(enqueued_locales_for(comment)).not_to include foreign.to_s
    end
  end

  describe "RemoteTranslation validation" do
    let(:comment) { Globalize.with_locale(foreign) { create(:comment) } }

    it "accepts the default locale when the source is another language" do
      record = RemoteTranslation.new(remote_translatable: comment, locale: source.to_s)
      record.source_locale = foreign.to_s

      expect(record).to be_valid
    end

    it "still rejects translating into the source locale" do
      record = RemoteTranslation.new(remote_translatable: comment, locale: source.to_s)
      record.source_locale = source.to_s

      expect(record).not_to be_valid
    end

    it "still rejects a locale the application does not serve" do
      record = RemoteTranslation.new(remote_translatable: comment, locale: "xx")

      expect(record).not_to be_valid
    end
  end
end
