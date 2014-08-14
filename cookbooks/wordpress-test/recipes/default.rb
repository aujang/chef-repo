#
# Cookbook Name:: wordpress-test
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe "apache2"
include_recipe "mysql::client"
include_recipe "mysql::server"
include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "apache2::mod_php5"
include_recipe "database::mysql"

apache_site "default" do
	enable false
end

mysql_database node['wordpress-test']['database'] do
	connection ({:host => 'localhost', :username => 'root', :password => node['mysql']['server_root_password']})
	action :create
end

mysql_database_user node['wordpress-test']['db_username'] do
	connection ({:host => 'localhost', :username => 'root', :password => node['mysql']['server_root_password']})
	password node['wordpress-test']['db_password']
	database_name node['wordpress-test']['database']
	privileges [:select,:update,:insert,:create,:delete]
	action :grant
end

wordpress_latest = Chef::Config[:file_cache_path] + "/wordpress-latest.tar.gz"

remote_file wordpress_latest do
	source "http://wordpress.org/latest.tar.gz"
	mode "0644"
end

directory node["wordpress-test"]["path"] do
	owner "root"
	group "root"
	mode "0755"
	action :create
	recursive true
end

execute "untar-wordpress" do
	cwd node['wordpress-test']['path']
	command "tar --strip-components 1 -xzf " + wordpress_latest
	creates node['wordpress-test']['path'] + "/wp-settings.php"
end

wp_secrets = Chef::Config[:file_cache_path] + '/wp-secrets.php'

if File.exist?(wp_secrets)
	salt_data = File.read(wp_secrets)
else
	require 'open-uri'
	salt_data = open('https://api.wordpress.org/secret-key/1.1/salt/').read
	open(wp_secrets, 'wb') do |file|
	file << salt_data
	end
end

template node['wordpress-test']['path'] + '/wp-config.php' do
	source 'wp-config.php.erb'
	mode 0755
	owner 'root'
	group 'root'
	variables(
		:database	=> node['wordpress-test']['database'],
		:user		=> node['wordpress-test']['db_username'],
		:password	=> node['wordpress-test']['db_password'],
		:wp_secrets	=> salt_data)
end

web_app 'wordpress-test' do
	template 'site.conf.erb'
	docroot node['wordpress-test']['path']
	server_name node['wordpress-test']['server_name']
end
