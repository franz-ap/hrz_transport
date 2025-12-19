#-------------------------------------------------------------------------------------------#
# Redmine utility/library plugin.                                                           #
# Provides common functions to other plugins,                                               #
#          a REST API for CustomField creation/modification,                                #
#          a transport utility for developers/admins.                                       #
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
# Purpose: Routes configuration for HRZ transport functionality.

RedmineApp::Application.routes.draw do
  # Transport functionality
  get 'hrz_transports', to: 'hrz_transports#index', as: 'hrz_transports'
  post 'hrz_transports/execute', to: 'hrz_transports#execute', as: 'hrz_transports_execute'
end
