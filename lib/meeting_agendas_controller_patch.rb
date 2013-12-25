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
        unless @object.nil? || (! @object.is_recording) || params[:continue_time].blank? || params[:continue_time].to_i == 0
          #update video
          video = VideoserverApi.call_api("recordings/#{@object.record_video_id}", :put, {'video[stop_time]' => Time.at(Time.now.to_i + params[:continue_time].to_i.minutes)})
          Rails.logger.info video.inspect
          render json: {minutes: params[:continue_time], stop_time: video['stop_time'].to_time.to_i, id: video['id']}
        end
      end

      def start_record
        find_object
        if @object && (! @object.is_recording) && @object.recordable?(User.current) && ((VideoserverApi.call_api("avaiables")["count"] || 0).try(:to_i) > 0)
          @video = VideoserverApi.call_api(File.basename(@object.online_meeting_url) + "/start_record/#{@object.end_time_utc.to_i}")
          @object.class.where(:id => @object.id).update_all(is_recording: true, record_video_id: (@video['id'] || 0).to_i, server_id: (@video['server_id'] || 0).to_i)
        elsif @object.is_recording
          @video = VideoserverApi.call_api("recordings/#{@object.record_video_id}")
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
        @object.notify_members_and_contacts
        send_invites_without_patch
      end

      def resend_invites_with_patch
        (render_403; return false) unless can_send_invites?(@object)
        @object.notify_members_and_contacts
        resend_invites_without_patch
      end
    end
  end
end