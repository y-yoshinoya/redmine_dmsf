# encoding: utf-8
#
# Redmine plugin for Document Management System "Features"
#
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

require File.expand_path('../../../test_helper', __FILE__)

class DmsfFileApiTest < RedmineDmsf::Test::IntegrationTest

  fixtures :projects, :users, :dmsf_files, :dmsf_file_revisions, :members, :roles, :member_roles

  def setup
    @jsmith = User.find_by_id 2
    @file1 = DmsfFile.find_by_id 1
    Setting.rest_api_enabled = '1'
    @role = Role.find_by_id 1
    @project1 = Project.find_by_id 1
    @project1.enable_module! :dmsf
  end

  def test_truth
    assert_kind_of User, @jsmith
    assert_kind_of DmsfFile, @file1
    assert_kind_of Role, @role
    assert_kind_of Project, @project1
  end

  def test_get_document
    @role.add_permission! :view_dmsf_files
    token = Token.create!(:user => @jsmith, :action => 'api')
    #curl -v -H "Content-Type: application/xml" -X GET -u ${1}:${2} http://localhost:3000/dmsf/files/17216.xml
    get "/dmsf/files/#{@file1.id}.xml?key=#{token.value}"
    assert_response :success
    assert_equal 'application/xml', @response.content_type
    #<?xml version="1.0" encoding="UTF-8"?>
    # <dmsf_file>
    #   <id>1</id>
    #   <name>test.txt</name>
    #   <project_id>1</project_id>
    #   <version>1.0</version>
    #   <mime_type>text/plain</mime_type>
    #   <digest>81dc9bdb52d04dc20036dbd8313ed055</digest>
    #   <size>4</size>
    #   <description>Some file :-)</description>
    #   <content_url>http://www.example.com/dmsf/files/1/download</content_url>
    # </dmsf_file>
    assert_select 'dmsf_file > id', :text => @file1.id.to_s
    assert_select 'dmsf_file > name', :text => @file1.name
    assert_select 'dmsf_file > project_id', :text => @file1.project_id.to_s
    assert_select 'dmsf_file > version', :text => "#{@file1.last_revision.major_version}.#{@file1.last_revision.minor_version}"
    assert_select 'dmsf_file > mime_type', :text => @file1.last_revision.mime_type
    assert_select 'dmsf_file > digest', :text => @file1.last_revision.digest
    assert_select 'dmsf_file > size', :text => @file1.last_revision.size.to_s
    assert_select 'dmsf_file > description', :text => @file1.last_revision.description
    assert_select 'dmsf_file > content_url', :text => "http://www.example.com/dmsf/files/#{@file1.id}/download"
    #curl -v -H "Content-Type: application/octet-stream" -X GET -u ${1}:${2} http://localhost:3000/dmsf/files/41532/download > file.txt
    Setting.plugin_redmine_dmsf['dmsf_storage_directory'] = File.expand_path '../../../fixtures/files', __FILE__
    get "/dmsf/files/#{@file1.id}/download.xml?key=#{token.value}"
    assert_response :success
    assert_equal '1234', @response.body
  end

  def test_upload_document
    timestamp = DateTime.now.strftime('%y%m%d%H%M')
    Setting.plugin_redmine_dmsf['dmsf_storage_directory'] = File.expand_path("./dmsf_test-#{timestamp}", DmsfHelper.temp_dir)
    FileUtils.mkdir_p(Setting.plugin_redmine_dmsf['dmsf_storage_directory'])
    @role.add_permission! :file_manipulation
    token = Token.create!(:user => @jsmith, :action => 'api')
    #curl --data-binary "@cat.gif" -H "Content-Type: application/octet-stream" -X POST -u ${1}:${2} http://localhost:3000/projects/12/dmsf/upload.xml?filename=cat.gif
    post "/projects/#{@project1.id}/dmsf/upload.xml?filename=test.txt&key=#{token.value}", 'File content', {"CONTENT_TYPE" => 'application/octet-stream'}
    assert_response :created
    assert_equal 'application/xml', response.content_type
    #<?xml version="1.0" encoding="UTF-8"?>
    # <upload>
    #   <token>2.8bb2564936980e92ceec8a5759ec34a8</token>
    # </upload>
    xml = Hash.from_xml(response.body)
    assert_kind_of Hash, xml['upload']
    ftoken = xml['upload']['token']
    assert_not_nil ftoken
    #curl -v -H "Content-Type: application/xml" -X POST --data "@file.xml" -u ${1}:${2} http://localhost:3000/projects/12/dmsf/commit.xml
    payload = %{
      <?xml version="1.0" encoding="utf-8" ?>
      <attachments>
       <folder_id/>
       <uploaded_file>
         <disk_filename>test.txt</disk_filename>
         <name>test.txt</name>
         <title>test.txt</title>
         <description>REST API</description>
         <comment>From API</comment>
         <version/>
         <token>#{ftoken}</token>
       </uploaded_file>
      </attachments>
    }
    post "/projects/#{@project1.id}/dmsf/commit.xml?&key=#{token.value}", payload, {"CONTENT_TYPE" => 'application/xml'}
    #<?xml version="1.0" encoding="UTF-8"?>
    #<dmsf_files total_count="1" type="array">
    # <file>
    #   <id>17229</id>
    #   <name>test.txt</name>
    # </file>
    # </dmsf_files>
    assert_select 'dmsf_files > file > name', :text => 'test.txt'
    assert_response :success
    begin
      FileUtils.rm_rf Setting.plugin_redmine_dmsf['dmsf_storage_directory']
    rescue Exception => e
      error e.message
    end
  end
end