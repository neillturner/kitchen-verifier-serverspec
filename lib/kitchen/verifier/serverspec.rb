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
    class Serverspec < Kitchen::Verifier::Base
      require 'mixlib/shellout'

      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :sleep, 0
      default_config :serverspec_command, nil
      default_config :custom_serverspec_command, nil
      default_config :additional_serverspec_command, nil
      default_config :shellout_opts, {}
      default_config :live_stream, $stdout
      default_config :remote_exec, true
      default_config :sudo_command, 'sudo -E -H'
      default_config :format, 'documentation'
      default_config :color, true
      default_config :default_path, '/tmp/kitchen'
      default_config :patterns, []
      default_config :default_pattern, false
      default_config :gemfile, nil
      default_config :custom_install_command, nil
      default_config :additional_install_command, nil
      default_config :test_serverspec_installed, true
      default_config :extra_flags, nil
      default_config :remove_default_path, false
      default_config :env_vars, {}
      default_config :bundler_path, nil
      default_config :rspec_path, nil
      default_config :require_runner, false
      default_config :runner_url, 'https://raw.githubusercontent.com/neillturner/serverspec-runners/master/ansiblespec_runner.rb'

      # (see Base#call)
      def call(state)
        info("[#{name}] Verify on instance=#{instance} with state=#{state}")
        sleep_if_set
        merge_state_to_env(state)
        if config[:remote_exec]
          if config[:default_pattern]
            create_sandbox
            sandbox_dirs = Dir.glob(File.join(sandbox_path, '*'))
          end
          instance.transport.connection(state) do |conn|
            conn.execute(install_command)
            if config[:default_pattern]
              info("Transferring files to #{instance.to_str}")
              conn.upload(sandbox_dirs, config[:root_path])
              debug('Transfer complete')
            end
            conn.execute(serverspec_commands)
          end
          cleanup_sandbox if config[:default_pattern]
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

      # (see Base#create_sandbox)
      def create_sandbox
        super
        prepare_suites
      end

      def serverspec_commands
        if config[:remote_exec]
          if custom_serverspec_command
            <<-INSTALL
            #{custom_serverspec_command}
            INSTALL
          else
            <<-INSTALL
            #{config[:additional_serverspec_command]}
            mkdir -p #{config[:default_path]}
            cd #{config[:default_path]}
            RSPEC_CMD=#{rspec_bash_cmd}
            echo $RSPEC_CMD
            #{rspec_commands}
            #{remove_default_path}
            INSTALL
          end
        elsif custom_serverspec_command
          shellout custom_serverspec_command
        else
          if config[:additional_serverspec_command]
            c = config[:additional_serverspec_command]
            shellout c
          end
          c = rspec_commands
          shellout c
        end
      end

      def install_command
        info('Installing with custom install command') if config[:custom_install_command]
        return config[:custom_install_command] if config[:custom_install_command]
        if config[:remote_exec]
          info('Installing ruby, bundler and serverspec remotely on server')
          <<-INSTALL
            #{config[:additional_install_command]}
            if [ ! $(which ruby) ]; then
              echo '-----> Installing ruby, will try to determine platform os'
              if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ] || [ -f /etc/oracle-release ]; then
                #{sudo_env('yum')} -y install ruby
              else
                if [ -f /etc/system-release ] && grep -q 'Amazon Linux' /etc/system-release; then
                  #{sudo_env('yum')} -y install ruby
                else
                  #{sudo_env('apt-get')} -y install ruby
                fi
              fi
            fi
            #{install_bundler}
            if [ -d #{config[:default_path]} ]; then
              #{install_serverspec}
              #{install_runner}
            else
              echo "ERROR: Default path '#{config[:default_path]}' does not exist"
              exit 1
            fi
          INSTALL
        else
          info('Installing bundler and serverspec locally on workstation')
          if config[:additional_install_command]
            c = config[:additional_install_command]
            shellout c
          end
          install_bundler
          install_serverspec
          install_runner
        end
      end

      # private

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
            shellout `gem install --no-ri --no-rdoc  bundler`
          end
        end
      end

      def install_runner
        return unless config[:require_runner]
        raise ActionFailed, 'Serverspec Runners only for remote execution' unless config[:remote_exec]
        <<-INSTALL
          if [ ! -f #{config[:default_path]}/#{runner_filename} ]; then
            #{sudo_env('curl')} -o #{config[:default_path]}/#{runner_filename} #{config[:runner_url]}
          fi
        INSTALL
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def install_serverspec
        if config[:remote_exec]
          <<-INSTALL
              #{test_serverspec_installed}
              #{install_gemfile}
              BUNDLE_CMD=#{bundler_cmd}
              echo $BUNDLE_CMD
              #{sudo_env('')} $BUNDLE_CMD install --gemfile=#{config[:default_path]}/Gemfile
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
            unless File.exist?(gemfile)
              File.open(gemfile, 'w') do |f|
                f.write("source 'https://rubygems.org'\ngem 'net-ssh','~> 2.9.4'\ngem 'serverspec'")
              end
            end
          end
          gemfile = config[:gemfile] if config[:gemfile]
          begin
            shellout "#{bundler_local_cmd} install --gemfile=#{gemfile}"
          rescue
            raise ActionFailed, 'Serverspec install failed'
          end
          nil
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
        config[:test_serverspec_installed] ? "if [ $(#{sudo('gem')} list serverspec -i) = 'false' ]; then" : nil
      end

      def fi_test_serverspec_installed
        config[:test_serverspec_installed] ? 'fi' : nil
      end

      def rspec_commands
        info('Running Serverspec')
        if config[:default_pattern]
          if config[:remote_exec]
            info("Using default pattern #{config[:root_path]}/serverspec/*_spec.rb")
            config[:patterns] = ["#{config[:root_path]}/serverspec/*_spec.rb"]
          else
            info("Using default pattern #{config[:test_base_path]}/#{config[:suite_name]}/serverspec/*_spec.rb")
            config[:patterns] = ["#{config[:test_base_path]}/#{config[:suite_name]}/serverspec/*_spec.rb"]
          end
        end
        if config[:require_runner]
          "#{env_vars} #{sudo_env(rspec_cmd)} #{color} -f #{config[:format]} --default-path  #{config[:default_path]} #{rspec_path_option} #{config[:extra_flags]}"
        elsif config[:remote_exec]
          config[:patterns].map { |s| "#{env_vars} #{sudo_env('')} $RSPEC_CMD #{color} -f #{config[:format]} --default-path  #{config[:default_path]} #{config[:extra_flags]} -P #{s}" }.join(';')
        else
          config[:patterns].map { |s| "#{env_vars} #{sudo_env(rspec_cmd)} #{color} -f #{config[:format]} --default-path  #{config[:default_path]} #{config[:extra_flags]} -P #{s}" }.join(';')
        end
      end

      def rspec_cmd
        config[:require_runner] ? "ruby #{config[:default_path]}/#{runner_filename}" : "#{rspec_path}rspec"
      end

      def env_vars
        return nil if config[:env_vars].none?
        cmd = nil
        if !config[:remote_exec]
          config[:env_vars].map do |k, v|
            info("Environment variable #{k} value #{v}")
            ENV[k.to_s] = v.to_s
          end
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

      def custom_serverspec_command
        return config[:custom_serverspec_command] if config[:custom_serverspec_command]
        config[:serverspec_command]
      end

      def bundler_cmd
        config[:bundler_path] ? "#{config[:bundler_path]}/bundle" : '$(which bundle)'
      end

      def bundler_local_cmd
        config[:bundler_path] ? "#{config[:bundler_path]}/bundle" : 'bundle'
      end

      def rspec_bash_cmd
        config[:rspec_path] ? "#{config[:rspec_path]}/rspec" : '$(which rspec)'
      end

      def rspec_path
        config[:rspec_path] ? "#{config[:rspec_path]}/" : nil
      end

      def rspec_path_option
        config[:rspec_path] ? "--rspec-path #{config[:rspec_path]}/" : nil
      end

      def runner_filename
        File.basename(config[:runner_url])
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
        command = command.strip
        info("Running command: #{command}")
        cmd = Mixlib::ShellOut.new(command, config[:shellout_opts])
        cmd.live_stream = config[:live_stream]
        cmd.run_command
        begin
          cmd.error!
        rescue Mixlib::ShellOut::ShellCommandFailed
          raise ActionFailed, "Command #{command.inspect} failed for #{instance.to_str}"
        end
      end

      def merge_state_to_env(state)
        env_state = { :environment => {} }
        env_state[:environment]['KITCHEN_INSTANCE'] = instance.name
        env_state[:environment]['KITCHEN_PLATFORM'] = instance.platform.name
        env_state[:environment]['KITCHEN_SUITE'] = instance.suite.name
        state.each_pair do |key, value|
          env_state[:environment]['KITCHEN_' + key.to_s.upcase] = value.to_s
          ENV['KITCHEN_' + key.to_s.upcase] = value.to_s
          info("Environment variable #{'KITCHEN_' + key.to_s.upcase} value #{value}")
        end
        # if using a driver that uses transport expose those too
        %w(username password ssh_key port).each do |key|
          next if instance.transport[key.to_sym].nil?
          value = instance.transport[key.to_sym].to_s
          ENV['KITCHEN_' + key.to_s.upcase] = value
          info("Transport Environment variable #{'KITCHEN_' + key.to_s.upcase} value #{value}")
        end
        config[:shellout_opts].merge!(env_state)
      end

      def chef_data_dir?(base, file)
        file =~ %r{^#{base}/(data|data_bags|environments|nodes|roles)/}
      end

      # Returns an Array of test suite filenames for the related suite currently
      # residing on the local workstation. Any special provisioner-specific
      # directories (such as a Chef roles/ directory) are excluded.
      #
      # @return [Array<String>] array of suite files
      # @api private
      def local_suite_files
        base = File.join(config[:test_base_path], config[:suite_name])
        glob = File.join(base, '*/**/*')
        Dir.glob(glob).reject do |f|
          chef_data_dir?(base, f) || File.directory?(f)
        end
      end

      # Copies all test suite files into the suites directory in the sandbox.
      def prepare_suites
        base = File.join(config[:test_base_path], config[:suite_name])
        debug("Creating local sandbox of all test suite files in #{base}")
        local_suite_files.each do |src|
          dest = File.join(sandbox_suites_dir, src.sub("#{base}/", ''))
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src, dest, :preserve => true)
        end
      end

      # @return [String] path to suites directory under sandbox path
      # @api private
      def sandbox_suites_dir
        File.join(sandbox_path, 'suites')
      end
    end
  end
end
