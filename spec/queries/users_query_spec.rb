require "rails_helper"

describe UsersQuery do
  let!(:confirmed)   { create(:user) }
  let!(:unconfirmed) { create(:user, :unconfirmed) }
  let!(:hidden)      { create(:user, hidden_at: Time.current) }

  def result(params)
    UsersQuery.new(User.with_hidden.all, ActionController::Parameters.new(params)).call
  end

  describe "status filter" do
    it "returns every status when the filter is absent" do
      expect(result({})).to contain_exactly(confirmed, unconfirmed, hidden)
    end

    it "returns only confirmed accounts" do
      expect(result(status: ["confirmed"])).to contain_exactly(confirmed)
    end

    it "returns only unconfirmed accounts" do
      expect(result(status: ["unconfirmed"])).to contain_exactly(unconfirmed)
    end

    it "returns only hidden accounts" do
      expect(result(status: ["hidden"])).to contain_exactly(hidden)
    end

    it "unions the selected statuses" do
      expect(result(status: %w[unconfirmed hidden])).to contain_exactly(unconfirmed, hidden)
    end

    it "ignores unknown status values" do
      expect(result(status: ["something_else"])).to contain_exactly(confirmed, unconfirmed, hidden)
    end

    it "combines with the email search" do
      expect(result(status: ["unconfirmed"], email__search: unconfirmed.email))
        .to contain_exactly(unconfirmed)
    end
  end
end
