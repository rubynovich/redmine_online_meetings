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
          format.json{render json: VideoserverApi.call_api("get_avaiables")}
          format.html{render json: VideoserverApi.call_api("get_avaiables")["count"]}
        end
      end

      def start_record
        find_object
        if @object.is_online? && (! @object.is_recording) && ((VideoserverApi.call_api("get_avaiables")["count"] || 0).try(:to_i) > 0)
          VideoserverApi.call_api(@object.online_meeting_uid.to_s + "/start_record")
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