
module DA_Deploy

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
      DA.system!("rsync -v --ignore-existing --exclude .git -e ssh --relative --recursive #{name}/#{release_id} #{server_name}:/deploy/apps/")
    }
  end # === def upload_commit_to_remote
  
end # === module DA_Deploy
