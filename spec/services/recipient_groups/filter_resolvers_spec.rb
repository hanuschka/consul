require "rails_helper"

describe RecipientGroups::FilterResolvers do
  describe ".for" do
    it "returns the matching resolver class" do
      stub_const("RecipientGroups::FilterResolvers::Foo", Class.new)
      expect(described_class.for("foo")).to eq(RecipientGroups::FilterResolvers::Foo)
    end

    it "raises when no resolver exists" do
      expect { described_class.for("nope") }.to raise_error(NameError)
    end
  end
end

describe RecipientGroups::FilterResolvers::Base do
  it "stores params with indifferent access" do
    resolver = described_class.new("foo" => "bar")
    expect(resolver.params[:foo]).to eq("bar")
  end

  it "requires subclasses to implement #emails" do
    resolver = described_class.new({})
    expect { resolver.emails }.to raise_error(NotImplementedError)
  end
end
