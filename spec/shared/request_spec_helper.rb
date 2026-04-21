module RequestSpecHelper
  include Warden::Test::Helpers

  def self.included(base)
    base.before { Warden.test_mode! }
    base.after { Warden.test_reset! }
  end

  def sign_in(resource)
    login_as(resource, scope: warden_scope(resource))
  end

  def sign_out(resource)
    logout(warden_scope(resource))
  end

  def base64_fixture(filename)
    encoded_fixtures[filename] ||= encode_fixture(filename)
  end

  private

    def encoded_fixtures
      @encoded_fixtures ||= {}
    end

    def encode_fixture(filename)
      fixture_path = Rails.root.join('spec', 'fixtures', 'files', filename)
      Base64.strict_encode64(File.read(fixture_path))
    end

    def warden_scope(resource)
      resource.class.name.underscore.to_sym
    end
end
