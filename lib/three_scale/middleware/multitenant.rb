# frozen_string_literal: true

module ThreeScale
  module Middleware

    class Multitenant
      def self.log(message)
        Rails.logger.debug "[MultiTenant] #{message}" if ENV['DEBUG']
      end

      class TenantChecker
        SKIPPED_CONTROLLERS = {
          "admin/api/objects".freeze => true, # this checks objects' tenant_id so we have to skip it
          "provider/domains".freeze => true,
        }.freeze
        private_constant :SKIPPED_CONTROLLERS

        attr_reader :original, :attribute

        class TenantLeak < StandardError
          def initialize(object, attribute, original)
            @object = object
            @attribute = attribute
            @original = original
          end

          def to_s
            "#{@object.class}:#{@object.id} has #{@attribute} #{@object.send(@attribute).inspect} but #{@original.inspect} already exists."
          end
        end

        def initialize(attribute, app, env)
          @original = nil
          @attribute = attribute
          @app = app
          @env = env
        end

        def verify!(object)
          return if SKIPPED_CONTROLLERS[@env["action_dispatch.request.path_parameters"][:controller]]

          # when the ActiveRecord object doesn't have tenant_id attribute at all
          unless object.respond_to?(attribute)
            # Multitenant.log "#{object} does not respond to: #{attribute}"
            return true
          end

          # reload object if it was partially loaded from db without the `tenant_id` attribute
          begin
            current = object.send(attribute)
          rescue ActiveRecord::MissingAttributeError
            # Multitenant.log("#{object} is missing #{attribute}. Reloading and trying again")
            fresh = object.class.unscoped.find(object.id, :select => attribute)
            current = fresh.send(attribute)
          end

          # this is when tenant_id is not set because of a bug or in older installations the master account has it nil
          return if current.nil?

          return if object.is_a?(::Account) && object.master? # some controllers refer to the master account

          # once initialized a legitimate AR object with a tenant_id, all others in the request should have the same
          @original ||= current

          return if current == original

          Thread.current[:multitenant] = nil # disable this checker as we either raise or user is master

          master? || raise(TenantLeak.new(object, attribute, original))
        end

        def master?
          return @is_master if defined?(@is_master)

          @is_master ||= @env["action_controller.instance"].send(:current_account)&.master?
        end
      end

      module EnforceTenant
        extend ActiveSupport::Concern

        included do
          after_initialize :enforce_tenant!
        end

        private

        def enforce_tenant!
          # Multitenant.log "initialized object #{self.class}:#{self.id}"
          Thread.current[:multitenant]&.verify!(self)
        end
      end

      def initialize(app, attribute)
        @app = app
        @attribute = attribute
        ActiveRecord::Base.send(:include, EnforceTenant)
      end

      def call(env)
        dup._call(env)
      end

      def _call(env)
        Thread.current[:multitenant] = TenantChecker.new(@attribute,@app,env)
        @app.call(env)
      ensure
        Thread.current[:multitenant] = nil
      end
    end
  end
end
