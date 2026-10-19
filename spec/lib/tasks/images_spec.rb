require "rails_helper"

describe "images:strip_metadata" do
  let(:report) do
    Images::StripStoredMetadataService::Report.new(stripped: 2, already_stripped: 1, exempt: 0, failed: 0)
  end

  before { Rake::Task["images:strip_metadata"].reenable }

  it "runs the metadata backfill and prints its progress and result" do
    allow(Images::StripStoredMetadataService).to receive(:call).and_yield(report, 100, 300).and_return(report)

    expect { Rake::Task["images:strip_metadata"].invoke }
      .to output(/100\/300: .*\nImage metadata: .*:stripped=>2/).to_stdout
  end
end
