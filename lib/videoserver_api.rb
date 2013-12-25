require 'uri'
require 'net/http'
require 'net/http/digest_auth'

class VideoserverApi

  attr_accessor :username
  attr_accessor :password
  attr_accessor :host
  attr_accessor :port
  attr_accessor :use_https
  cattr_accessor :api


  def initialize
    @username = Setting[:plugin_redmine_online_meetings][:videoserver_username]
    @password = Setting[:plugin_redmine_online_meetings][:videoserver_password]
    @host = Setting[:plugin_redmine_online_meetings][:videoserver_host]
    @port = Setting[:plugin_redmine_online_meetings][:videoserver_port]
    @use_https = (Setting[:plugin_redmine_online_meetings][:videoserver_https] || '').to_s == "1"
  end

  def self.call_api(function, method=:get, data={})
    self.api ||= self.new
    self.api.call_api(function, method, data)
  end


  def call_api_post_put(url, method, data)
    uri = URI.parse url
    uri.user = @username
    uri.password = @password
    h = Net::HTTP.new uri.host, uri.port
    req = Net::HTTP::Get.new uri.request_uri
    res = h.request req
    digest_auth = Net::HTTP::DigestAuth.new
    auth = digest_auth.auth_header uri, res['www-authenticate'], (method == :put ? 'PUT' : 'POST')
    klass = (method == :put ? Net::HTTP::Put : Net::HTTP::Post)
    req = klass.new uri.request_uri
    req.set_form_data(data)
    req.add_field 'Authorization', auth
    req.add_field("Accept", "application/json")
    res = h.request req
    if res.code == '200'
      #return res
      begin
        r = JSON.parse(res.body)
      rescue
        r = {error_content: c.body_str}
      end
      Rails.logger.info r.inspect
      return r
    else
      raise "http error #{res.code}"
    end
  end

  def call_api(function, method=:get, data={})
    url = "http#{'s' if @use_https}://#{@host}#{':'+(@port || '')  .to_s unless self.port.blank? || @port.try(:to_i) == 80}/api/#{function}"
    unless method == :get
      return call_api_post_put(url, method, data)
    end
    url = "http#{'s' if @use_https}://#{@host}#{':'+(@port || '')  .to_s unless self.port.blank? || @port.try(:to_i) == 80}/api/#{function}"
    c = Curl::Easy.new(url)
    Rails.logger.info url
    Rails.logger.info data.inspect
    #raise "http#{'s' if @use_https}://#{@host}#{':'+(@port || '')  .to_s unless self.port.blank? || @port.try(:to_i) == 80}/api/#{function}"
    c.http_auth_types = :digest
    c.username = @username
    c.password = @password
    c.enable_cookies = true
    c.perform
    if [:post, :put].include?(method)
      pars = Rack::Utils.build_nested_query(data)
      Rails.logger.info pars.inspect
      method == :post ? c.http_post(pars) : c.http_put(pars)
    end
    begin
      res = JSON.parse(c.body_str)
    rescue
      res = {error_content: c.body_str}
    end
    Rails.logger.info res.inspect
    res
  end
end