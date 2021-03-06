#

require 'json'
require 'api_utils'

module Occam
  module WebService
    module ActiveModel

      class APIv1 < Grape::API

        version :v1, :using => :path, :vendor => "occam"
        format :json
        default_format :json
        SLICE_REF = ProjectOccam::Slice::ActiveModel.new([])

        rescue_from ProjectOccam::Error::Slice::InvalidUUID do |e|
          Rack::Response.new(
              Occam::WebService::Response.new(400, e.class.name, e.message).to_json,
              400,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from ProjectOccam::Error::Slice::MethodNotAllowed do |e|
          Rack::Response.new(
              Occam::WebService::Response.new(403, e.class.name, e.message).to_json,
              403,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from Grape::Exceptions::Validation do |e|
          Rack::Response.new(
              Occam::WebService::Response.new(400, e.class.name, e.message).to_json,
              400,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from :all do |e|
          raise e
          Rack::Response.new(
              Occam::WebService::Response.new(500, e.class.name, e.message).to_json,
              500,
              { "Content-type" => "application/json" }
          )
        end

        helpers do

          def content_type_header
            settings[:content_types][env['api.format']]
          end

          def api_format
            env['api.format']
          end

          def is_uuid?(string_)
            string_ =~ /^[A-Za-z0-9]{1,22}$/
          end

          def get_data_ref
            Occam::WebService::Utils::get_data
          end

          def request_is_from_occam_server(ip_addr)
            Occam::WebService::Utils::request_from_occam_server?(ip_addr)
          end

          def request_is_from_occam_subnet(ip_addr)
            Occam::WebService::Utils::request_from_occam_subnet?(ip_addr)
          end

          def get_active_model_by_uuid(uuid)
            active_model = SLICE_REF.get_object("active_model_instance", :active, uuid)
            raise ProjectOccam::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{uuid}]" unless active_model && (active_model.class != Array || active_model.length > 0)
            active_model
          end

          def get_logs_for_active_model(active_model, with_uuid = false)
            # Take each element in our attributes_hash and store as a HashPrint object in our array
            last_time = nil
            first_time = nil
            log_entries = []
            index = 0
            active_model.model.log.each { |log_entry|
              entry_time = Time.at(log_entry["timestamp"])
              entry_time_int = entry_time.to_i
              first_time ||= entry_time
              last_time ||= entry_time
              total_time_diff = entry_time - first_time
              last_time_diff = entry_time - last_time
              hash_entry = { :State => active_model.state_print(log_entry["old_state"].to_s,log_entry["state"].to_s),
                             :Action => log_entry["action"].to_s,
                             :Result => log_entry["result"].to_s,
                             :Time => entry_time.strftime('%Y-%m-%d %H:%M:%S %Z'),
                             :Last => active_model.pretty_time(last_time_diff.to_i),
                             :Total => active_model.pretty_time(total_time_diff.to_i)
              }
              hash_entry[:NodeUUID] = active_model.node_uuid if with_uuid
              log_entries << hash_entry
              last_time = Time.at(log_entry["timestamp"])
              index = index + 1
            }
            log_entries
          end

          def slice_success_response(slice, command, response, options = {})
            Occam::WebService::Utils::rz_slice_success_response(slice, command, response, options)
          end

          def slice_success_object(slice, command, response, options = {})
            Occam::WebService::Utils::rz_slice_success_object(slice, command, response, options)
          end

        end

        resource :active_model do

          # GET /active_model
          # Retrieve list of active_models.
          desc "Retrieve a list of all active_model instances"
          get do
            active_models = SLICE_REF.get_object("active_models", :active)
            slice_success_object(SLICE_REF, :get_all_active_models, active_models, :success_type => :generic)
          end     # end GET /active_model

          # the following description hides this endpoint from the swagger-ui-based documentation
          # (since the functionality provided by this endpoint is not intended to be used off of
          # the Occam server)
          desc 'Hide this endpoint', {
              :hidden => true
          }
          resource '/logs' do

            # GET /active_model
            # Retrieve all active_model logs.
            desc "Returns the log entries for all active_model instances"
            before do
              # only allow access to this resource from the Occam subnet
              unless request_is_from_occam_server(env['REMOTE_ADDR'])
                raise ProjectOccam::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /active_model/logs resource is only allowed from Occam server"
              end
            end
            get do
              active_models = SLICE_REF.get_object("active_models", :active)
              log_items = []
              active_models.each { |bp| log_items = log_items | get_logs_for_active_model(bp, true) }
              log_items.sort! { |a, b| a[:Time] <=> b[:Time] }
              slice_success_response(SLICE_REF, :get_active_model_logs, log_items, :success_type => :generic)
            end     # end GET /active_model/logs

          end     # end resource /active_model/logs

          resource '/:uuid' do

            # GET /active_model/{uuid}
            # Retrieve a specific active_model (by UUID).
            desc "Return the details for a specific active_model instance"
            params do
              requires :uuid, type: String, desc: "The active_model's UUID"
            end
            get do
              uuid = params[:uuid]
              active_model = get_active_model_by_uuid(uuid)
              slice_success_object(SLICE_REF, :get_active_model_by_uuid, active_model, :success_type => :generic)
            end     # end GET /active_model/{uuid}


            # DELETE /active_model/{uuid}
            # Remove an active_model instance (by UUID)
            desc "Remove an active_model instance"
            before do
              # only allow access to this resource from the Occam subnet
              unless request_is_from_occam_subnet(env['REMOTE_ADDR'])
                raise ProjectOccam::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /active_model/{uuid} resource is only allowed from Occam subnet"
              end
            end
            params do
              requires :uuid, type: String, desc: "The active_model's UUID"
            end
            delete do
              active_model_uuid = params[:uuid]
              active_model = SLICE_REF.get_object("active_model_instance", :active, active_model_uuid)
              raise ProjectOccam::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{active_model_uuid}]" unless active_model && (active_model.class != Array || active_model.length > 0)
              raise ProjectOccam::Error::Slice::CouldNotRemove, "Could not remove Active Model [#{active_model.uuid}]" unless get_data_ref.delete_object(active_model)
              slice_success_response(SLICE_REF, :remove_active_model_by_uuid, "Active Model [#{active_model.uuid}] removed", :success_type => :removed)
            end     # end DELETE /active_model/{uuid}

            # the following description hides this endpoint from the swagger-ui-based documentation
            # (since the functionality provided by this endpoint is not intended to be used off of
            # the Occam server)
            desc 'Hide this endpoint', {
                :hidden => true
            }
            resource '/logs' do

              # GET /active_model/{uuid}/logs
              # Retrieve the log for an active_model (by UUID).
              desc "Returns the log entries for a specific active_model instance"
              before do
                # only allow access to this resource from the Occam subnet
                unless request_is_from_occam_server(env['REMOTE_ADDR'])
                  raise ProjectOccam::Error::Slice::MethodNotAllowed, "Access to /active_model/{uuid}/logs resource is only allowed from Occam server"
                end
              end
              params do
                requires :uuid, type: String, desc: "The active_model's UUID"
              end
              get do
                uuid = params[:uuid]
                active_model = get_active_model_by_uuid(uuid)
                log_items = get_logs_for_active_model(active_model)
                slice_success_response(SLICE_REF, :get_active_model_logs, log_items, :success_type => :generic)
              end     # end GET /active_model/{uuid}/logs

            end     # end resource /active_model/:uuid/logs

          end     # end resource /active_model/:uuid

        end     # end resource /active_model

      end

    end

  end

end
