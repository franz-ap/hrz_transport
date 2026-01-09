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
# Purpose: Plugin registration file for the Redmine transport utility plugin.

require 'redmine'

Redmine::Plugin.register :hrz_transport do
  name        'HRZ Transport'
  author      'Franz Apeltauer, Claude'
  description 'Redmine transport utility plugin for developers/admins. It helps you to compare Custom fields in two different Redmine instances and to copy them from/to the other instance.'
  version     '0.6.2'
  url         'https://github.com/franz-ap/hrz_transport'
  author_url ''
  requires_redmine version_or_higher: '6.1.0'

  # Uses methods from the library plugin hrz_lib:
  requires_redmine_plugin :hrz_lib, version_or_higher: '0.5.0'

  # Add settings with default values
  settings default: {
    'transport_target_url' => ''
  }, partial: 'settings/hrz_transport_settings'

  # Add menu item in admin menu
  menu :admin_menu, :hrz_transports,
       { controller: 'hrz_transports', action: 'index' },
       caption: :label_hrz_transports,
       html: { class: 'icon icon-package' }
end

# Load library module
require_relative 'lib/hrz_transport/transport_helper'
