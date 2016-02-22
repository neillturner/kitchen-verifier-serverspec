# -*- encoding: utf-8 -*-
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen/verifier/base'

module Kitchen
  module Verifier
    # Serverspec verifier for Kitchen.
    #
    class Serverspec < Kitchen::Verifier::Base
      require 'mixlib/shellout'

      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :sleep, 0
      default_config :serverspec_command, nil
      default_config :shellout_opts, {}
      default_config :live_stream, $stdout
      default_config :remote_exec, true
      default_config :format, 'documentation'
      default_config :color, true
      default_config :default_path, '/tmp/kitchen'
      default_config :patterns, []
      default_config :gemfile, nil
      default_config :install_commmand, 'bundle install'
      default_config :test_serverspec_installed, true
      default_config :extra_flags, nil
      default_config :remove_default_path, false
      default_config :env_vars, {}
      default_config :bundle_path, nil
      default_config :rspec_path,  nil

      # (see Base#call)
      def call(state)
        info("[#{name}] Verify on instance=#{instance} with state=#{state}")
        sleep_if_set
        merge_state_to_env(state)
        if config[:remote_exec]
          instance.transport.connection(state) do |conn|
            conn.execute(install_command)
            conn.execute(serverspec_commands)
          end
        else
          config[:default_path] = Dir.pwd if config[:default_path] == '/tmp/kitchen'
          install_command
          serverspec_commands
        end
        debug("[#{name}] Verify completed.")
      end

      ## for legacy drivers.
      def run_command
        sleep_if_set
        serverspec_commands
      end

      def setup_cmd
        sleep_if_set
        install_command
      end

      private

      def serverspec_commands
        if config[:remote_exec]
          if config[:serverspec_command]
            <<-INSTALL
            #{config[:serverspec_command]}
            INSTALL
          else
            <<-INSTALL
            if [ -d #{config[:default_path]} ]; then
              cd #{config[:default_path]}
              #{rspec_commands}
              #{remove_default_path}
            else
              echo "ERROR: Default path '#{config[:default_path]}' does not exist"
              exit 1
            fi
            INSTALL
          end
        elsif config[:serverspec_command]
            info("Running command: #{config[:serverspec_command]}")
            system config[:serverspec_command]
          else
            x = rspec_commands
            info("Running command: #{x}")
            system x
          end
        end
      end

      def install_command
        if config[:remote_exec]
          info('Installing ruby, bundler and serverspec')
          <<-INSTALL
            if [ ! $(which ruby) ]; then
              echo '-----> Installing ruby, will try to determine platform os'
              if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ] || [ -f /etc/oracle-release ]; then
                #{sudo_env('yum')} -y install ruby
              else
                if [ -f /etc/system-release ] || [ grep -q 'Amazon Linux' /etc/system-release ]; then
                  #{sudo_env('yum')} -y install ruby
                else
                  #{sudo_env('apt-get')} -y install ruby
                fi
              fi
            fi
            #{install_bundler}
            if [ -d #{config[:default_path]} ]; then
              #{install_serverspec}
            else
              echo "ERROR: Default path '#{config[:default_path]}' does not exist"
              exit 1
            fi
          INSTALL
        else
          info('Installing bundler and serverspec')
          install_bundler
          install_serverspec
        end
      end

      def install_bundler
        if config[:remote_exec]
          <<-INSTALL
            if [ $(#{sudo('gem')} list bundler -i) == 'false' ]; then
              #{sudo_env('gem')} install #{gem_proxy_parm} --no-ri --no-rdoc bundler
            fi
          INSTALL
        else
          begin
            require 'bundler'
          rescue LoadError
            system `gem install --no-ri --no-rdoc  bundler`
          end
        end
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def install_serverspec
        if config[:remote_exec]
          bundler_cmd = "#{bundler_path}bundler"
          <<-INSTALL
              #{test_serverspec_installed}
              #{install_gemfile}
              #{sudo_env(bundler_cmd)} install --gemfile=#{config[:default_path]}/Gemfile
            #{fi_test_serverspec_installed}
          INSTALL
        else
          if config[:test_serverspec_installed]
            begin
              require 'serverspec'
              return
            rescue LoadError
              info('serverspec not installed installing ...')
            end
          end
          unless config[:gemfile]
            gemfile = "#{config[:default_path]}/Gemfile"
            File.open(gemfile, 'w') do |f|
              f.write("source 'https://rubygems.org'\ngem 'net-ssh','~> 2.9.4'\ngem 'serverspec'")
            end
          end
          gemfile = config[:gemfile] if config[:gemfile]
          begin
            system "bundler install --gemfile=#{gemfile}"
          rescue
            raise ActionFailed, 'Serverspec install failed'
          end
        end
      end

      def install_gemfile
        if config[:gemfile]
          <<-INSTALL
          #{read_gemfile}
          INSTALL
        else
          <<-INSTALL
          #{sudo('rm')} -f #{config[:default_path]}/Gemfile
          #{sudo('echo')} "source 'https://rubygems.org'" >> #{config[:default_path]}/Gemfile
          #{sudo('echo')} "gem 'net-ssh','~> 2.9'"  >> #{config[:default_path]}/Gemfile
          #{sudo('echo')} "gem 'serverspec'" >> #{config[:default_path]}/Gemfile
          INSTALL
        end
      end

      def read_gemfile
        data = "#{sudo('rm')} -f #{config[:default_path]}/Gemfile\n"
        f = File.open(config[:gemfile], 'r')
        f.each_line do |line|
          data = "#{data}#{sudo('echo')} \"#{line}\" >> #{config[:default_path]}/Gemfile\n"
        end
        f.close
        data
      end

      def remove_default_path
        info('Removing default path') if config[:remove_default_path]
        config[:remove_default_path] ? "rm -rf #{config[:default_path]}" : nil
      end

      def test_serverspec_installed
        config[:test_serverspec_installed] ? "if [ $(#{sudo('gem')} list serverspec -i) == 'false' ]; then" : nil
      end

      def fi_test_serverspec_installed
        config[:test_serverspec_installed] ? 'fi' : nil
      end

      def rspec_commands
        rspec_cmd = "#{rspec_path}rspec"
        info('Running Serverspec')
        config[:patterns].map { |s| "#{env_vars} #{sudo_env(rspec_cmd)} #{color} -f #{config[:format]} --default-path  #{config[:default_path]} #{config[:extra_flags]} -P #{s}" }.join('\n')
      end

      def env_vars
        return nil if config[:env_vars].none?
        cmd = nil
        if !config[:remote_exec]
          config[:env_vars].map { |k, v|
            info("Environment variable #{k} value #{v}")
            ENV[k.to_s] = v.to_s
          }
        else
          cmd = config[:env_vars].map { |k, v| "#{k}=#{v}" }.join(' ')
          debug(cmd)
        end
        cmd
      end

      def sudo_env(pm)
        if config[:remote_exec]
          s = https_proxy ? "https_proxy=#{https_proxy}" : nil
          p = http_proxy ? "http_proxy=#{http_proxy}" : nil
          p || s ? "#{sudo('env')} #{p} #{s} #{pm}" : sudo(pm).to_s
        else
          # TODO: handle proxies
          pm
        end
      end

      def bundler_path
        config[:bundler_path] ? "#{config[:bundler_path]}/" : nil
      end

      def rspec_path
        config[:rspec_path] ? "#{config[:rspec_path]}/" : nil
      end

      def http_proxy
        config[:http_proxy]
      end

      def https_proxy
        config[:https_proxy]
      end

      def gem_proxy_parm
        http_proxy ? "--http-proxy #{http_proxy}" : nil
      end

      def color
        config[:color] ? '-c' : nil
      end

      # Sleep for a period of time, if a value is set in the config.
      #
      # @api private
      def sleep_if_set
        config[:sleep].to_i.times do
          print '.'
          sleep 1
        end
      end

      def shellout(command)
        info("Running command: #{command}")
        cmd = Mixlib::ShellOut.new(command, config[:shellout_opts])
        cmd.live_stream = config[:live_stream]
        cmd.run_command
        begin
          cmd.error!
        rescue Mixlib::ShellOut::ShellCommandFailed
          raise ActionFailed, "Action #verify failed for #{instance.to_str}."
        end
      end

      def merge_state_to_env(state)
        env_state = { :environment => {} }
        env_state[:environment]['KITCHEN_INSTANCE'] = instance.name
        env_state[:environment]['KITCHEN_PLATFORM'] = instance.platform.name
        env_state[:environment]['KITCHEN_SUITE'] = instance.suite.name
        state.each_pair do |key, value|
          env_state[:environment]['KITCHEN_' + key.to_s.upcase] = value
        end
        config[:shellout_opts].merge!(env_state)
      end
    end
  end
end
