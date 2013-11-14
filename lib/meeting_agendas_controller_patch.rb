require_dependency 'meeting_agendas_controller'
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