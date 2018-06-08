

require "da"
require "inspect_bang"
require "file_utils"

module DA_Deploy

  DEPLOY_DIR = ENV["IS_DEVELOPMENT"]? ? "/tmp/deploy" : "/deploy"
  SERVICE_DIR = ENV["IS_DEVELOPMENT"]? ? "/tmp/var/service" : "/var/service"

  extend self

  def deploy
    Dir.glob("#{DEPLOY_DIR}/apps/*/").each { |dir|
      deploy(dir)
    }
  end

  def deploy(name : String)
    sv = Runit.new(name)

    Dir.cd(sv.app_dir)

    if !sv.latest_release
      DA.exit_with_error!("No service found for: #{sv.name}")
    end

    if sv.latest_linked?
      DA.exit_with_error! "=== Already installed: #{sv.service_link} -> #{`realpath #{sv.service_link}`}"
    end

    if sv.linked?
      sv.down! if sv.run?
      sv.wait_pids
      if sv.any_pids_up?
        DA.exit_with_error!("!!! Pids still up for #{name}: #{sv.pids_up}")
      end
      DA.system!("sudo rm -f #{sv.service_link}")
    end

    sv.link!

    new_service = Runit.new(name)
    sleep 5
    wait(5) { new_service.run?  }
    puts Runit.status(new_service.service_link)
    if !new_service.run?
      Process.exit 1
    end
  end # === def deploy

  def wait(max : Int32)
    counter = 0
    result = false
    while counter < max
      result = yield
      break if result
      counter += 1
      sleep 1
    end
    result
  end # === def wait

  def generate_release_id
    `git show -s --format=%ct-%h`.strip
  end

  def service_name?(name : String, dir : String)
    dir_name = File.dirname(dir)
    dir_name =~ /^#{name}\.\d{10}-[\da-zA-Z]{7}$/
  end # === def service_name?

  def self.is_release?(dir)
    File.basename(dir)[/^\d{10}-[\da-zA-Z]{7}$/]?
  end

  def self.releases(name : String)
    Dir.glob("#{DEPLOY_DIR}/apps/#{name}/*/").sort.map { |dir|
      next unless is_release?(dir)
      dir
    }.compact
  end

  def self.latest_release(name : String)
    d = releases(name).last?
    if !d || !File.directory?(d)
      DA.exit_with_error!("!!! No latest release found for #{name}")
    end
    d
  end # === def self.latest_release

  def service_run
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

  def upload_shell_config_to(server_name : String)
    bin_path = Process.executable_path.not_nil!
    app_dir = File.join(
      File.dirname(File.dirname(bin_path))
    )
    Dir.cd(app_dir)
    Dir.cd("config/deployer/")
    DA.system!("rsync -v -e ssh --relative --recursive .config/fish #{server_name}:/home/deployer/")
  end # === def upload_shell_config

  # Push the bin/da_deploy binary to /tmp on the remote server
  def upload_binary_to_remote(server_name : String)
    dir = File.dirname(File.dirname(Process.executable_path.not_nil!))
    Dir.cd(dir)
    DA.system!("rsync", "-v -e ssh --relative --recursive bin #{server_name}:/home/deployer/".split)
    # DA.orange! "=== {{Run command on remote}}: BOLD{{/home/deployer/da_deploy init}}"
    # DA.system!("ssh #{server_name}")
  end # === def init_server

  def upload_commit_to_remote(server_name : String)
    release_id = generate_release_id
    name = File.basename(Dir.current)
    path = Dir.current
    FileUtils.mkdir_p "tmp/#{name}"
    Dir.cd("tmp/#{name}") {
      FileUtils.rm_rf(release_id)
      DA.system!("git clone --depth 1 file://#{path} #{release_id}")
    }
    remote_dir = "/deploy/apps/#{name}/#{release_id}"
    system("ssh #{server_name} test -d #{remote_dir}")
    if DA.success?($?)
      DA.exit_with_error!("!!! Already exists on server: #{remote_dir}")
    end
    Dir.cd("tmp") {
      DA.system!("rsync -v --ignore-existing -e ssh --relative --recursive #{name}/#{release_id} #{server_name}:/deploy/apps/")
    }
  end # === def upload_commit_to_remote

  # Run this on the remote server you want to setup.
  def init
    if ENV["IS_DEVELOPMENT"]?
      STDERR.puts "!!! Not a production machine."
      Process.exit 1
    end

    app_name = File.basename(Process.executable_path || self.to_s.downcase)
    required_services = "dhcpcd sshd ufw nanoklogd socklog-unix".split

    Dir.cd("/") {
      if Dir.exists?(DEPLOY_DIR) 
        DA.orange! "=== {{DONE}}: BOLD{{directory}} #{DEPLOY_DIR}"
      else
        DA.system!("sudo mkdir #{DEPLOY_DIR}")
        DA.system!("sudo chown #{ENV["USER"]} #{DEPLOY_DIR}")
      end
    }

    DA::VoidLinux.install("git", "git")
    DA::VoidLinux.install("rsync", "rsync")
    DA::VoidLinux.install("nvim", "neovim")
    DA::VoidLinux.install("fish", "fish-shell")
    DA::VoidLinux.install("htop", "htop")
    DA::VoidLinux.install("socklog", "socklog-void")
    DA::VoidLinux.install("ufw", "ufw")
    DA::VoidLinux.install("wget", "wget")
    DA::VoidLinux.install("curl", "curl")

    DA.system! "test -e #{SERVICE_DIR}/dhcpcd"
    DA.system! "test -e #{SERVICE_DIR}/sshd"
    DA.system! "test -e #{SERVICE_DIR}/ufw"
    DA.system! "test -e #{SERVICE_DIR}/nanoklogd"
    DA.system! "test -e #{SERVICE_DIR}/socklog-unix"

    init_ssh
    DA.green! "=== {{Done}}: BOLD{{init deploy}}"
  end # === def init_deploy

  def init_www
    "www-deployer www-data".split.each { |user|
      id = `id -u #{user}`.strip
      if id.empty?
        DA.system!("sudo useradd --system #{user}")
      else
        DA.orange! "=== User exists: #{user}"
      end
    }
  end

  def init_ssh
    file = "/etc/ssh/sshd_config"
    File.read(file).split('\n').map { |l| l.split }.each { |pieces|
      count  = pieces.size
      first  = pieces[0]?
      second = pieces[1]?
      next if first && first.index('#') == 0
      next if !first
      case first.upcase
      when "PermitRootLogin".upcase, "PasswordAuthentication".upcase, "UsePAM".upcase
        next if second == "no"
      when "ChallengeResponseAuthentication".upcase
        next if second == "no"
      else
        next
      end

      DA.exit_with_error!("!!! Invalid value for sshd_config: #{pieces.join ' '}")
    }

    Dir.cd(ENV["HOME"]) {
      DA.system!("chmod 700 -R .ssh")
      Dir.cd(".ssh") {
        contents = (File.exists?("authorized_keys") ? File.read("authorized_keys") : "").strip
        if contents.empty?
          DA.exit_with_error!("!!! authorized_keys empty.")
        else
          DA.system!("sudo sv restart sshd")
        end
      }
    }
  end # === def init_ssh

end # === module DA_Deploy

require "./da_deploy/Runit"
