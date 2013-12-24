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

  def call_api(function, method=:get, data={})
    url = "http#{'s' if @use_https}://#{@host}#{':'+(@port || '')  .to_s unless self.port.blank? || @port.try(:to_i) == 80}/api/#{function}"
    c = Curl::Easy.new(url)
    #raise "http#{'s' if @use_https}://#{@host}#{':'+(@port || '')  .to_s unless self.port.blank? || @port.try(:to_i) == 80}/api/#{function}"
    c.http_auth_types = :digest
    c.username = @username
    c.password = @password
    if method == :get
      c.perform
    elsif [:post, :put].include?(method)
      pars = []
      data.each_pair do |name, content|
        pars << Curl::PostField.content(name,content)
      end
      method.post? ? c.post(pars) : c.put(url, pars)
    end
    begin
      res = JSON.parse(c.body_str)
    rescue
      res = {error_content: c.body_str}
    end
    Rails.logger.info   res.inspect
    res
  end
end