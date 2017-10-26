# encoding: utf-8
#
# Redmine plugin for Document Management System "Features"
#
# Copyright (C) 2011    Vít Jonáš <vit.jonas@gmail.com>
# Copyright (C) 2011-17 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class DmsfStateController < ApplicationController
  unloadable
  
  menu_item :dmsf
  
  before_action :find_project
  before_action :authorize

  def user_pref_save
    member = @project.members.where(:user_id => User.current.id).first
    if member
      member.dmsf_mail_notification = params[:email_notify]
      member.title_format = params[:title_format]
      if format_valid?(member.title_format) && member.save
        flash[:notice] = l(:notice_your_preferences_were_saved)
      else
        flash[:error] = l(:notice_your_preferences_were_not_saved)
      end
    else
      flash[:warning] = l(:user_is_not_project_member)
    end
    if Setting.plugin_redmine_dmsf['dmsf_act_as_attachable']
      @project.update_attribute :dmsf_act_as_attachable, params[:act_as_attachable]
    end
    redirect_to settings_project_path(@project, :tab => 'dmsf')
  end
  
  private
  
  def format_valid?(format)
    format.blank? || ((format =~ /%(t|d|v|i|r)/) && format.length < 256)
  end
    
end