class GCalApi
  def initialize(options={})
    client = Google::APIClient.new
    key = Google::APIClient::PKCS12.load_key(options[:key_file], 'notasecret')
    service_account = Google::APIClient::JWTAsserter.new(
        options[:gserviceaccount],
        'https://www.googleapis.com/auth/prediction',
        key)
    client.authorization = service_account.authorize
    client
  end

end