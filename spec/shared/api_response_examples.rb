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
    body_parameter_names = declared_body_parameter_names

    response '401', ApiResponseExamples::UNAUTHORIZED_DESCRIPTION do
      let(:Authorization) { 'Bearer invalid_token' }
      body_parameter_names.each { |parameter_name| let(parameter_name) { {} } }
      instance_exec(&path_params) if path_params

      schema ApiResponseExamples::ERROR_SCHEMA

      run_test! do |response|
        expect(JSON.parse(response.body)['error']['type']).to eq('unauthorized')
      end
    end
  end

  def forbidden_response(&setup)
    body_parameter_names = declared_body_parameter_names

    response '403', ApiResponseExamples::FORBIDDEN_DESCRIPTION do
      before { api_client.update_column(:access_level, nil) }
      body_parameter_names.each { |parameter_name| let(parameter_name) { {} } }
      instance_exec(&setup) if setup

      schema ApiResponseExamples::ERROR_SCHEMA

      run_test! do |response|
        expect(JSON.parse(response.body)['error']['type']).to eq('forbidden')
      end
    end
  end

  # rswag requires a `let` for every declared body parameter, even for
  # examples where the payload is irrelevant (401/403 short-circuit before
  # the body is read).
  def declared_body_parameter_names
    operation_parameters = metadata.dig(:operation, :parameters) || []

    operation_parameters
      .select { |parameter| parameter[:in].to_s == 'body' }
      .map { |parameter| parameter[:name] }
      .compact
  end
end
