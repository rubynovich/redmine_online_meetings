module GCal4RubyPatch
  module Service
    extend ActiveSupport::Concern
    included do
      attr_accessor :hangout_domain
      cattr_accessor :get
      def self.get(force=nil)
        service = self.class_variable_get(:@@get)
        if service.nil? || force
          service = GCal4Ruby::Service.new
          service.hangout_domain = Setting[:plugin_redmine_online_meetings][:hangout_domain]
          service.authenticate(Setting[:plugin_redmine_online_meetings][:account_login], Setting[:plugin_redmine_online_meetings][:account_password])
          self.class_variable_set(:@@get, service)
        end
        service
      end
    end

  end
  module Event
    extend ActiveSupport::Concern
    included do
      EVENT_XML = "<entry xmlns='http://www.w3.org/2005/Atom'
          xmlns:gd='http://schemas.google.com/g/2005' xmlns:gCal='http://schemas.google.com/gCal/2005'
          xmlns:gAcl='http://schemas.google.com/acl/2007'
          xmlns:georss='http://www.georss.org/georss'
          xmlns:gml='http://www.opengis.net/gml'
          xmlns:openSearch='http://a9.com/-/spec/opensearch/1.1/'>
        <category scheme='http://schemas.google.com/g/2005#kind'
          term='http://schemas.google.com/g/2005#event'></category>
        <title type='text'></title>
        <content type='text'></content>
        <gd:transparency
          value='http://schemas.google.com/g/2005#event.opaque'>
        </gd:transparency>
        <gd:eventStatus
          value='http://schemas.google.com/g/2005#event.confirmed'>
        </gd:eventStatus>
        <gd:where valueString=''></gd:where>
        <gd:when startTime=''
          endTime=''></gd:when>
      </entry>"

      VISIBILITY = { :default => "http://schemas.google.com/g/2005#event.default",
          :private => "http://schemas.google.com/g/2005#event.private",
          :public => "http://schemas.google.com/g/2005#event.public"
      }

      attr_reader :hangout_uid
      attr_reader :alternate_uri
      attr_reader :event_alternate_uri
      attr_accessor :hangout_domain
      attr_accessor :visibility
      attr_accessor :is_video_conference
    end

    def full_save
      self.save
      if @is_video_conference
        self.reload
        self.save
        #hardcode: open video conference HACK!
        doc = self.service.send_request(GData4Ruby::Request.new(:get, @event_alternate_uri))
        if html = doc.body
          if secid = html[/secid\\x3e\\x3cvalue\\x3e(.*)\\x3c\/value\\x3e\\x3c\/secid/,1]
            @hangout_domain ||= self.service.hangout_domain
            google_request = GData4Ruby::Request.new(:post, "#{@event_alternate_uri}&sprop=goo.rtc%3A3&sprop=goo.rtcParam%3A&sprop=goo.rtcDomain%3A#{@hangout_domain}&sf=true&output=js&secid=#{secid}&action=EDIT")
            google_request.calculate_length!
            self.service.send_request(google_request)
          end
        end
        self.reload
      end
    end

    #Loads the event info from an XML string.
    def load(string)
      super(string)
      @xml = string
      @exists = true
      xml = REXML::Document.new(string)
      @etag = xml.root.attributes['etag']

      xml.root.elements.each(){}.map do |ele|
        case ele.name
          when 'id'
            @calendar_id, @id = @feed_uri.gsub("http://www.google.com/calendar/feeds/", "").split("/events/")
            @id = "#{@calendar_id}/private/full/#{@id}"
          when 'edited'
            @edited = Time.parse(ele.text)
          when 'content'
            @content = ele.text
          when "when"
            @start_time = Time.parse(ele.attributes['startTime'])
            @end_time = Time.parse(ele.attributes['endTime'])
            @all_day = !ele.attributes['startTime'].include?('T')
            @reminder = []
            ele.elements.each("gd:reminder") do |r|
              rem = {}
              rem[:minutes] = r.attributes['minutes'] if r.attributes['minutes']
              rem[:method] = r.attributes['method'] if r.attributes['method']
              @reminder << rem
            end
          when "where"
            @where = ele.attributes['valueString']
          when "link"
            if ele.attributes['rel'] == 'edit'
              @edit_feed = ele.attributes['href']
            elsif ele.attributes['rel'] == 'alternate' && ele.attributes['title'] == 'alternate'
              @event_alternate_uri = ele.attributes['href']
              @hangout_uid = File.basename(@event_alternate_uri)[-30..-1]
            end
          when "who"
            @attendees << {:email => ele.attributes['email'], :name => ele.attributes['valueString'], :role => ele.attributes['rel'].gsub("http://schemas.google.com/g/2005#event.", ""), :status => ele.elements["gd:attendeeStatus"] ? ele.elements["gd:attendeeStatus"].attributes['value'].gsub("http://schemas.google.com/g/2005#event.", "") : ""}
          when "eventStatus"
            @status =  ele.attributes["value"].gsub("http://schemas.google.com/g/2005#event.", "").to_sym
          when 'recurrence'
            @recurrence = Recurrence.new(ele.text)
          when 'visibility'
            @visibility = ele.attributes["value"].gsub("http://schemas.google.com/g/2005#event.", "").to_sym
          when 'videoConference'
            if ele.attributes["service"] == 'hangout' && ele.attributes["value"].present?
              @hangout_uid = ele.attributes["value"][/^(.*?)\./,1]
              @is_video_conference = true
              ele.elements.to_a('link').each do |el|
                if el.attributes['rel'] == 'alternate'
                  @alternate_uri = el.attributes['href']
                end
              end
              @alternate_uri ||= "https://plus.google.com/hangouts/_/calendar/#{@hangout_uid}.#{uid}" if @id && uid = File.basename(@id)
            end
          when "transparency"
            @transparency = case ele.attributes["value"]
                              when "http://schemas.google.com/g/2005#event.transparent" then :free
                              when "http://schemas.google.com/g/2005#event.opaque" then :busy
                            end
        end
      end
    end

    #Returns an XML representation of the event.
    def to_xml()
      xml = REXML::Document.new(super)
      xml.root.add_element("gCal:videoConference") if @is_video_conference && xml.root.elements["gCal:videoConference"].nil?
      xml.root.elements.each(){}.map do |ele|
        case ele.name
          when "content"
            ele.text = @content
          when "when"
            if not @recurrence
              puts 'all_day = '+@all_day.to_s if service.debug
              if @all_day
                puts 'saving as all-day event' if service.debug
              else
                puts 'saving as timed event' if service.debug
              end
              ele.attributes["startTime"] = @all_day ? @start_time.strftime("%Y-%m-%d") : @start_time.utc.xmlschema
              ele.attributes["endTime"] = @all_day ? @end_time.strftime("%Y-%m-%d") : @end_time.utc.xmlschema
              set_reminder(ele)
            else
              xml.root.delete_element("/entry/gd:when")
              ele = xml.root.add_element("gd:recurrence")
              ele.text = @recurrence.to_recurrence_string
              set_reminder(ele) if @reminder
            end
          when "eventStatus"
            ele.attributes["value"] = GCal4Ruby::Event::STATUS[@status]
          when "transparency"
            ele.attributes["value"] = GCal4Ruby::Event::TRANSPARENCY[@transparency]
          when "visibility"
            ele.attributes["value"] = GCal4Ruby::Event::VISIBILITY[@visibility]
          when "where"
            ele.attributes["valueString"] = @where
          when 'videoConference'
            if @id && @hangout_uid && uid = File.basename(@id)
              ele.attributes['service'] = 'hangout'
              ele.attributes['value'] = "#{@hangout_uid}.#{uid}"
              ele_link = nil
              ele.elements.to_a('link').each do |el|
                ele_link = el if el.attributes['rel'] == 'alternate'
              end
              unless ele_link
                ele_link = ele.add_element('link')
                ele_link.attributes['rel'] = 'alternate'
              end
              ele_link.attributes['href'] = "https://plus.google.com/hangouts/_/calendar/#{@hangout_uid}.#{uid}"
              ele_link.attributes['type'] = 'text/html'
            else
              #add clear link
              ele.attributes['service'] = 'hangout'
              ele.attributes['value'] = ''
              ele_link = ele.add_element('link')
              ele_link.attributes['rel'] = 'alternate'
              ele_link.attributes['type'] = 'text/html'
              ele_link.attributes['href'] = ''
            end
          when "recurrence"
            puts 'recurrence element found' if service.debug
            if @recurrence
              puts 'setting recurrence' if service.debug
              ele.text = @recurrence.to_recurrence_string
            else
              puts 'no recurrence, adding when' if service.debug
              w = xml.root.add_element("gd:when")
              xml.root.delete_element("/entry/gd:recurrence")
              w.attributes["startTime"] = @all_day ? @start_time.strftime("%Y-%m-%d") : @start_time.xmlschema
              w.attributes["endTime"] = @all_day ? @end_time.strftime("%Y-%m-%d") : @end_time.xmlschema
              set_reminder(w)
            end
        end
      end
      if not @attendees.empty?
        xml.root.elements.delete_all "gd:who"
        @attendees.each do |a|
          xml.root.add_element("gd:who", {"email" => a[:email], "valueString" => a[:name], "rel" => "http://schemas.google.com/g/2005#event.attendee"})
        end
      end
      xml.to_s
    end

  end
end

