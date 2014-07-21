require_dependency 'meeting_agendas_controller'
require 'smsc_api'
require 'videoserver_api'
module OnlineMeetings
  module MeetingAgendasControllerPatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        begin
          alias_method_chain :send_invites, :patch
          alias_method_chain :resend_invites, :patch
        rescue
          #TODO for Redmine 2.3
        end
      end
    end

    module ClassMethods
    end

    module InstanceMethods

      def issue
        find_object
        (render_403; return false) unless can_show_agenda?(@object) || (@object.meeting_members.map{|member| member.user_id}).include?(User.current.id)
        if meeting_member = @object.meeting_members.where({user_id: User.current.id}).first
          redirect_to controller: 'issues', action: 'show', id: meeting_member.issue_id
        else
          (render_403; return false)
        end
      end

      def show_avaiable_servers
        respond_to do |format|
          format.json{render json: VideoserverApi.call_api("avaiables")}
          format.html{render json: VideoserverApi.call_api("avaiables")["count"]}
        end
      end

      def continue_record
        find_object
        unless @object.nil? || (! @object.is_recording) || params[:stop_time].blank? || params[:stop_time].to_i == 0
          #update video
          video = VideoserverApi.call_api("recordings/#{@object.record_video_id}", :put, {'video[stop_time]' => Time.at(params[:stop_time].to_i)})
          Rails.logger.info video.inspect
          render json: {stop_time: (video['stop_time']).to_time.to_i, id: video['id']}
          return
        end
        unless @object.nil? || (! @object.is_recording) || params[:add_minutes].present? || params[:add_minutes].to_i == 0
          video = VideoserverApi.call_api("recordings/#{@object.record_video_id}", :put, {'video[stop_time]' => Time.at((@object.end_time_utc > Time.now.utc ? @object.end_time_utc : Time.now.utc) + params[:add_minutes].to_i.minutes)})
          Rails.logger.info video.inspect
          render json: {stop_time: (video['stop_time']).to_time.to_i, id: video['id']}
          return
        end
        unless @object.nil? || (! @object.is_recording)
          video = VideoserverApi.call_api("recordings/#{@object.record_video_id}", :get)
          render json: {stop_time: (video['stop_time']).to_time.to_i, id: video['id']}
          #render json: {stop_time: @object.end_time_utc.to_i, video_id: @object.record_video_id}
        else
          render json: {stop_time: (Time.now.utc - 1.day).to_i}
        end
      end

      def start_record
        find_object
        unless @object || (@object.author_id == User.current.id)
          render_403
          return
        end
        if @object && (! @object.is_recording) && @object.recordable?(User.current) && ((VideoserverApi.call_api("avaiables")["count"] || 0).try(:to_i) > 0)
          @video = VideoserverApi.call_api(File.basename(@object.online_meeting_url) + "/start_record/#{@object.end_time_utc.to_i}")
          #hard code
          @object.class.where(:id => @object.id).update_all(is_recording: true, record_video_id: (@video['id'] || 0).to_i, server_id: (@video['server_id'] || 0).to_i)
          @object = @object.class.where(:id => @object.id).first
        elsif @object.is_recording
          @video = VideoserverApi.call_api("recordings/#{@object.record_video_id}")
        else
          Rails.logger.error "ERROR FATALITY: object - #{@object.inspect}; avail - #{(VideoserverApi.call_api("avaiables")["count"] || 0).try(:to_i)} "
          #@video = Video.last.attributes
          render :text => "ERROR FATALITY: object - #{@object.inspect}; avail - #{(VideoserverApi.call_api("avaiables")["count"] || 0).try(:to_i)} "
          return
        end
        respond_to do |format|
          format.json {render json: {status: @video}}
          format.html {render}
        end
      end

      def stop_record
        find_object
        if @object.is_recording?
          video = VideoserverApi.call_api(@object.record_video_id.to_s + "/stop_record")
          MeetingAgenda.where(:id=>@object.id).update_all(["is_recording = false"])
          #@object.is_recording = false
          #@obejctrecord_video_id: nil)
        end
        respond_to do |format|
          format.json {render json: {status: :ok}}
          format.html {redirect_to @object}
        end
      end

      def send_invites_with_patch
        (render_403; return false) unless can_send_invites?(@object)
        @object.sidekiq_delay.notify_members_and_contacts
        send_invites_without_patch
      end

      def resend_invites_with_patch
        (render_403; return false) unless can_send_invites?(@object)
        @object.sidekiq_delay.notify_members_and_contacts
        resend_invites_without_patch
      end
    end
  end
end