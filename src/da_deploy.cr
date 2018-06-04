

require "da"
require "file_utils"

module DA_Deploy

  DEPLOY_DIR = ENV["IS_DEVELOPMENT"]? ? "/tmp/deploy" : "/deploy"
  SERVICE_DIR = ENV["IS_DEVELOPMENT"]? ? "/tmp/var/service" : "/var/service"

  extend self

  def generate_id
    `git show -s --format=%ct-%h`.strip
  end

  def watch
    counter = 0
    interval = 5
    STDERR.puts "=== Started watching at: #{Time.now.to_s}"
    loop {
      sleep interval
      counter += interval

      if (counter % 5) == 0
        Dir.glob("#{DEPLOY_DIR}/*/").each { |dir|
          next unless Dir.exists?(File.join dir, "releases")
          app_name = File.basename(dir)
          # init_sv(app_name) if !Dir.exists?("#{DEPLOY_DIR}/sv/#{app_name}")
        }
      end
    }
  end # === def deploy_watch

  # Push the bin/da binary to /tmp on the remote server
  def upload_to_remote(server_name : String)
    DA.system!("rsync", "-v -e ssh #{Process.executable_path} #{server_name}:/home/stager/".split)
    DA.orange! "=== {{Run command on remote}}: BOLD{{/home/stager/da_deploy init}}"
    DA.system!("ssh #{server_name}")
  end # === def init_server


  def create_services(folder : String)
    puts "=== Creating services for: #{folder}"
  end

  # Run this on the remote server you want to setup.
  def init
    app_name = File.basename(Process.executable_path || self.to_s.downcase)
    required_services = "dhcpcd sshd ufw nanoklogd socklog-unix".split

    if ENV["IS_DEVELOPMENT"]
      FileUtils.mkdir_p SERVICE_DIR
      required_services.each { |x|
        FileUtils.mkdir_p "#{SERVICE_DIR}/#{x}"
      }
    end

    Dir.cd("/") {
      if Dir.exists?(DEPLOY_DIR) 
        DA.orange! "=== {{DONE}}: BOLD{{directory}} #{DEPLOY_DIR}"
      else
        DA.system!("sudo mkdir #{DEPLOY_DIR}")
        DA.system!("sudo chown #{ENV["USER"]} #{DEPLOY_DIR}")
      end
    }

    DA.system! "test -e #{SERVICE_DIR}/dhcpcd"
    DA.system! "test -e #{SERVICE_DIR}/sshd"
    DA.system! "test -e #{SERVICE_DIR}/ufw"
    DA.system! "test -e #{SERVICE_DIR}/nanoklogd"
    DA.system! "test -e #{SERVICE_DIR}/socklog-unix"

    DA.system! "mkdir -p #{DEPLOY_DIR}/apps/#{app_name}/bin"
    DA.system! "mv -f #{Process.executable_path} #{DEPLOY_DIR}/apps/#{app_name}/bin/"

    Dir.cd("#{DEPLOY_DIR}/apps/#{app_name}") {
      dir = "sv/deploy_watch"
      if Dir.exists?(dir)
        DA.system! "sudo chown #{ENV["USER"]} #{dir}/run"
        DA.system! "sudo chown #{ENV["USER"]} #{dir}/log/run"
      else
        DA.system! "mkdir -p #{dir}/log"
      end

      File.write("#{dir}/run", {{system("cat templates/sv/run").stringify}})
      File.write("#{dir}/log/run", {{system("cat templates/sv/log").stringify}})

      DA.system! "chmod +x #{dir}/run"
      DA.system! "chmod +x #{dir}/log/run"
      DA.system! "sudo chown --recursive root:root #{dir}"

      service = "#{SERVICE_DIR}/#{app_name}_watch"
      if File.exists?(service)
        DA.system! "sudo sv restart #{service}"
      else
        DA.system! "sudo ln -s #{DEPLOY_DIR}/apps/#{dir} #{service}"
      end
    }

    DA.green! "=== {{Done}}: BOLD{{init deploy}}"
  end # === def init_deploy
end # === module DA_Deploy
