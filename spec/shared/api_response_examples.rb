module ApiResponseExamples
  UNAUTHORIZED_DESCRIPTION = 'unauthorized - missing or invalid token'
  FORBIDDEN_DESCRIPTION = 'forbidden - insufficient access'

  ERROR_SCHEMA = {
    type: :object,
    properties: {
      error: {
        type: :object,
        properties: {
          type: { type: :string },
          messages: { type: :array, items: { type: :string } }
        }
      }
    }
  }.freeze

  def unauthorized_response(&path_params)
    response '401', ApiResponseExamples::UNAUTHORIZED_DESCRIPTION do
      let(:Authorization) { 'Bearer invalid_token' }
      instance_exec(&path_params) if path_params

      schema ApiResponseExamples::ERROR_SCHEMA

      run_test! do |response|
        expect(JSON.parse(response.body)['error']['type']).to eq('unauthorized')
      end
    end
  end

  def forbidden_response(&setup)
    response '403', ApiResponseExamples::FORBIDDEN_DESCRIPTION do
      before { api_client.update_column(:access_level, nil) }
      instance_exec(&setup) if setup

      schema ApiResponseExamples::ERROR_SCHEMA

      run_test! do |response|
        expect(JSON.parse(response.body)['error']['type']).to eq('forbidden')
      end
    end
  end
end
