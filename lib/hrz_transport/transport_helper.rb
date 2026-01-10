#-------------------------------------------------------------------------------------------#
# Redmine transport utility plugin for developers/admins.                                   #
# Copyright (C) 2025 Franz Apeltauer                                                        #
#                                                                                           #
# This program is free software: you can redistribute it and/or modify it under the terms   #
# of the GNU Affero General Public License as published by the Free Software Foundation,    #
# either version 3 of the License, or (at your option) any later version.                   #
#                                                                                           #
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; #
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. #
# See the GNU Affero General Public License for more details.                               #
#                                                                                           #
# You should have received a copy of the GNU Affero General Public License                  #
# along with this program.  If not, see <https://www.gnu.org/licenses/>.                    #
#-------------------------------------------------------------------------------------eohdr-#
# Purpose: Helper module for transporting custom field definitions between Redmine instances.

require 'json'

module HrzTransport
  class TransportHelper
    
    # Get the base URL of the target Redmine instance.
    # @return [String, nil] ... Redmine base URL. nil, if unknown.
    def self.get_target_base_url
      b_target_url = Setting.plugin_hrz_transport['transport_target_url']
      return nil   if b_target_url.nil? || b_target_url.blank?
      # Normalize URL (remove trailing slash if present)
      b_target_url = b_target_url.chomp('/')
    end  # get_target_base_url



    # Fetches instance information from target instance
    # @param api_key [String] API key for authentication
    # @return [Hash, nil] Instance info hash, or nil on error
    def self.fetch_target_instance_info(api_key)
      begin
        b_target_url = get_target_base_url()
        return nil   if b_target_url.nil? || b_target_url.blank?

        hsh_res = HrzLib::HrzHttp.http_request(b_target_url + '/hrz_custom_fields/instance_info.json',
                                               'GET',
                                               {'X-Redmine-API-Key' => api_key, 'Content-Type' => 'application/json'},
                                               nil,
                                               'fetch_target_instance_info')
        if hsh_res[:q_ok]
          data = JSON.parse(hsh_res[:body])
          return data['instance_info'].deep_symbolize_keys
        else
          # Error already reported. # Rails.logger.error "HRZ Transport: Failed to fetch instance info. Status: #{response.code}, Body: #{response.body}"
          return nil
        end
      rescue => e
        HrzLib::HrzLogger.error_msg "HRZ TransportHelper.fetch_target_instance_info: Error fetching instance info: #{e.message}"
        HrzLib::HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # fetch_target_instance_info

    
    
    # Fetches custom fields from target instance
    # @param api_key [String] API key for authentication
    # @return [Array<Hash>, nil] Array of custom field hashes, or nil on error
    def self.fetch_target_custom_fields(api_key)
      begin
        b_target_url = get_target_base_url()
        return nil   if b_target_url.nil? || b_target_url.blank?
        
        hsh_res = HrzLib::HrzHttp.http_request(b_target_url + '/hrz_custom_fields.json',
                                               'GET',
                                               {'X-Redmine-API-Key' => api_key, 'Content-Type' => 'application/json'},
                                               nil,
                                               'fetch_target_custom_fields')
        if hsh_res[:q_ok]
          data = JSON.parse(hsh_res[:body])
          fields_count = data['custom_fields'].length
          HrzLib::HrzLogger.debug_msg "HRZ TransportHelper.fetch_target_custom_fields: Successfully fetched #{fields_count} custom fields"
          return data['custom_fields'].map(&:deep_symbolize_keys)
        else
          # Error already reported. #Rails.logger.error "HRZ TransportHelper.fetch_target_custom_fields: Failed to fetch target fields. Status: #{response.code}, Body: #{response.body}"
          return nil
        end
      rescue => e
        HrzLib::HrzLogger.error_msg "HRZ TransportHelper.fetch_target_custom_field: Error fetching target fields: #{e.message}"
        HrzLib::HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # fetch_target_custom_fields

    
    
    # Fetches detailed information about a specific custom field from target instance
    # @param field_id [Integer] The ID of the custom field
    # @param api_key [String] API key for authentication
    # @return [Hash, nil] Custom field details, or nil on error
    def self.fetch_target_field_details(field_id, api_key)
      begin
        b_target_url = get_target_base_url()
        return nil   if b_target_url.nil? || b_target_url.blank?

        hsh_res = HrzLib::HrzHttp.http_request(b_target_url + "/hrz_custom_fields/#{field_id}.json",
                                               'GET',
                                               {'X-Redmine-API-Key' => api_key, 'Content-Type' => 'application/json'},
                                               nil,
                                               'fetch_target_custom_fields')
        if hsh_res[:q_ok]
          data = JSON.parse(hsh_res[:body])
          # Rails.logger.info "HRZ Transport: Successfully fetched field details for ##{field_id}"
          return data['custom_field'].deep_symbolize_keys
        else
          # Error already reported. #Rails.logger.error "HRZ Transport: Failed to fetch field details. Status: #{response.code}"
          return nil
        end
      rescue => e
        HrzLib::HrzLogger.error_msg "HRZ TransportHelper.fetch_target_field_details: Error fetching target field ##{field_id} details: #{e.message}"
        return nil
      end
    end  # fetch_target_field_details
    
    

    # Compares local and target custom fields
    #
    # @param local_fields [Array<Hash>] Local custom fields
    # @param target_fields [Array<Hash>] Target custom fields
    #
    # @return [Array<Hash>] Array of comparison results
    def self.compare_custom_fields(local_fields, target_fields)
      results = []
      
      Rails.logger.info "HRZ Transport: Comparing #{local_fields.length} local fields with #{target_fields.length} target fields"
      
      local_fields.each do |local_field|
        # Find matching field in target by name and type
        target_field = target_fields.find do |tf|
          tf[:name] == local_field[:name] && 
          tf[:customized_type] == local_field[:customized_type]
        end
        
        comparison = {
          local_id: local_field[:id],
          name: local_field[:name],
          local_type: local_field[:field_format],
          customized_type: local_field[:customized_type],
          exists_in_target: !target_field.nil?,
          target_id: target_field&.dig(:id),
          is_identical: false,
          differences: []
        }
        
        if target_field
          # Compare field properties
          comparison[:is_identical] = compare_field_properties(local_field, target_field, comparison[:differences])
        else
          comparison[:differences] << {
            property: 'existence',
            local_value: 'exists',
            target_value: 'does not exist'
          }
        end
        
        results << comparison
      end
      
      Rails.logger.info "HRZ Transport: Comparison complete. Found #{results.count { |r| r[:is_identical] }} identical and #{results.count { |r| !r[:is_identical] }} different fields"
      
      results
    end  # compare_custom_fields
    
    

    # Compares properties of two custom fields
    #
    # @param local_field [Hash] Local field properties
    # @param target_field [Hash] Target field properties
    # @param differences [Array] Array to collect differences
    #
    # @return [Boolean] true if fields are identical
    def self.compare_field_properties(local_field, target_field, differences)
      identical = true
      
      # Get detailed information for comparison
      local_details = HrzLib::CustomFieldHelper.get_custom_field(local_field[:id])
      
      # Compare name
      if local_details[:name] != target_field[:name]
        differences << {
          property: 'name',
          local_value: local_details[:name],
          target_value: target_field[:name]
        }
        identical = false
      end
      
      # Compare field format
      if local_details[:field_format] != target_field[:field_format]
        differences << {
          property: 'field_format',
          local_value: local_details[:field_format],
          target_value: target_field[:field_format]
        }
        identical = false
      end
      
      # Compare required status
      if local_details[:is_required] != target_field[:is_required]
        differences << {
          property: 'is_required',
          local_value: local_details[:is_required],
          target_value: target_field[:is_required]
        }
        identical = false
      end
      
      # Compare possible values for list fields
      if local_details[:field_format] == 'list'
        local_values = (local_details[:possible_values] || []).sort
        target_values = (target_field[:possible_values] || []).sort
        
        if local_values != target_values
          differences << {
            property: 'possible_values',
            local_value: local_values.join(', '),
            target_value: target_values.join(', ')
          }
          identical = false
        end
      end
      
      # Compare default value
      if local_details[:default_value] != target_field[:default_value]
        differences << {
          property: 'default_value',
          local_value: local_details[:default_value] || '(none)',
          target_value: target_field[:default_value] || '(none)'
        }
        identical = false
      end
      
      # Compare formula for computed fields
      if local_details[:formula] || target_field[:formula]
        if local_details[:formula] != target_field[:formula]
          differences << {
            property: 'formula',
            local_value: local_details[:formula] || '(none)',
            target_value: target_field[:formula] || '(none)'
          }
          identical = false
        end
      end
      
      identical
    end  # compare_field_properties
    

    
    # Executes a transport operation
    #
    # @param field_id [Integer] Local custom field ID
    # @param direction [String] 'local_to_target' or 'target_to_local'
    # @param api_key [String] API key for authentication
    # @param doc_issue_local [String, nil] Local documentation issue ID
    # @param doc_issue_target [String, nil] Target documentation issue ID
    #
    # @return [Hash] Result with :success, :field_name, and :error keys
    def self.execute_transport(field_id, direction, api_key, doc_issue_local, doc_issue_target)
      begin
        if direction == 'local_to_target'
          result = transport_local_to_target(field_id, api_key)
        elsif direction == 'target_to_local'
          result = transport_target_to_local(field_id, api_key)
        else
          return {success: false, error: 'Invalid transport direction'}
        end
        
        if result[:success]
          # Add documentation notes if issue IDs provided
          add_documentation_note(doc_issue_local, result[:message], 'local') if doc_issue_local.present?
          add_documentation_note(doc_issue_target, result[:message], 'target', api_key) if doc_issue_target.present?
        end
        
        result
        
      rescue => e
        Rails.logger.error "HRZ Transport: Transport execution failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        {success: false, error: e.message}
      end
    end  # execute_transport
    
    

    # Transports a custom field definition from local to target instance
    #
    # @param local_field_id [Integer] Local custom field ID
    # @param api_key [String] API key for authentication
    #
    # @return [Boolean] true: ok, false: error/problems. Infos were already issued here inside.
    def self.transport_local_to_target(local_field_id, api_key)
      begin
        # Get local field details
        local_field = HrzLib::CustomFieldHelper.get_custom_field(local_field_id)
        return {success: false, error: 'Local field not found'} if local_field.nil?
        
        target_url = get_target_base_url()
        return {success: false, error: 'Target URL not configured'} if target_url.blank?
        
        # Check if field exists in target
        target_fields = fetch_target_custom_fields(api_key)
        target_field = target_fields&.find do |tf|
          tf[:name] == local_field[:name] && 
          tf[:customized_type] == local_field[:customized_type]
        end
        
        # Prepare field data
        field_data = prepare_field_data_for_transport(local_field)
        
        #                                                          Update existing field --V                     /  create a new field -V
        hsh_res = HrzLib::HrzHttp.http_request(b_target_url +
                                                  (target_field ? "/hrz_custom_fields/#{target_field[:id]}.json" : '/hrz_custom_fields.json'),
                                               (target_field    ? 'PUT'                                          : 'POST'),
                                               {'X-Redmine-API-Key' => api_key, 'Content-Type' => 'application/json'},
                                               {custom_field: field_data}.to_json,
                                               'transport_local_to_target(' + (target_field ? 'Upd' : 'Cre') + "_CF '#{local_field[:name]}')",
                                               [200, 201] )
        if hsh_res[:q_ok]
          HrzLib::HrzLogger.info_msg (target_field ? 'Updated' : 'Created') + " CustomField '#{local_field[:name]}' in target instance."
        end
         hsh_res[:q_ok]
      rescue => e
        HrzLib::HrzLogger.error_msg "HRZ TransportHelper.transport_local_to_target Error: #{e.message}"
        HrzLib::HrzLogger.error_msg e.backtrace.join("\n")
      end
    end  # transport_local_to_target

    
    
    # Transports a custom field definition from target to local instance
    #
    # @param local_field_id [Integer] Local custom field ID (used to identify the field by name/type)
    # @param api_key [String] API key for authentication
    #
    # @return [Hash] Result with :success, :field_name, :message, and :error keys
    def self.transport_target_to_local(local_field_id, api_key)
      begin
        # Get local field to identify which field to fetch from target
        local_field = HrzLib::CustomFieldHelper.get_custom_field(local_field_id)
        return {success: false, error: 'Local field not found'} if local_field.nil?
        
        # Find matching field in target
        target_fields = fetch_target_custom_fields(api_key)
        target_field_summary = target_fields&.find do |tf|
          tf[:name] == local_field[:name] && 
          tf[:customized_type] == local_field[:customized_type]
        end
        
        return {success: false, error: 'Field not found in target instance'} if target_field_summary.nil?
        
        # Get detailed target field information
        target_field = fetch_target_field_details(target_field_summary[:id], api_key)
        return {success: false, error: 'Could not fetch target field details'} if target_field.nil?
        
        # Prepare field data (exclude read-only fields)
        field_data = prepare_field_data_for_transport(target_field)
        
        # Update local field
        success = HrzLib::CustomFieldHelper.update_custom_field(local_field_id, field_data)
        
        if success
          message = "Updated custom field '#{local_field[:name]}' from target instance"
          {success: true, field_name: local_field[:name], message: message}
        else
          {success: false, field_name: local_field[:name], error: 'Failed to update local field'}
        end
        
      rescue => e
        {success: false, error: e.message}
      end
    end  # transport_target_to_local
    
    

    # Prepares field data for transport (removes read-only and instance-specific fields)
    #
    # @param field [Hash] Field details
    #
    # @return [Hash] Cleaned field data ready for transport
    def self.prepare_field_data_for_transport(field)
      # Remove read-only and instance-specific fields
      data = field.except(:id, :created_at, :updated_at, :position)
      
      # Ensure arrays are properly formatted
      data[:possible_values] = data[:possible_values].to_a if data[:possible_values]
      data[:project_ids] = data[:project_ids].to_a if data[:project_ids]
      data[:tracker_ids] = data[:tracker_ids].to_a if data[:tracker_ids]
      data[:role_ids] = data[:role_ids].to_a if data[:role_ids]
      
      data
    end  # prepare_field_data_for_transport

    
    
    # Adds a documentation note to an issue
    #
    # @param issue_id [String, Integer] Issue ID
    # @param message [String] Note text
    # @param location [String] 'local' or 'target'
    # @param api_key [String, nil] API key (required for target)
    def self.add_documentation_note(issue_id, message, location, api_key = nil)
      begin
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        note_text = "[#{timestamp}] Custom Field Transport: #{message}"
        
        if location == 'local'
          # Add note to local issue
          HrzLib::IssueHelper.add_comment(issue_id.to_i, note_text)
        elsif location == 'target' && api_key
          # Add note to target issue via API
          target_url = get_target_base_url()
          return if target_url.blank?
          hsh_res = HrzLib::HrzHttp.http_request(b_target_url + "/issues/#{issue_id}.json",
                                                 'PUT',
                                                 {'X-Redmine-API-Key' => api_key, 'Content-Type' => 'application/json'},
                                                 { issue: { notes: note_text } }.to_json,
                                                 'add_documentation_note' )
          if hsh_res[:q_ok]
            HrzLib::HrzLogger.info_msg "Added documentation note to #{location} issue ##{issue_id}"
          end
      rescue => e
        HrzLib::HrzLogger.error_msg "HRZ TransportHelper.add_documentation_note: Failed to add #{location} documentation note: #{e.message}"
        HrzLib::HrzLogger.error_msg e.backtrace.join("\n")
      end
    end  # add_documentation_note
    
  end  # class TransportHelper
end  # module HrzTransport
