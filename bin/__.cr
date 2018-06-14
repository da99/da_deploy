
require "../src/da_deploy"
full_cmd = ARGV.map(&.strip).join(' ')


case
when "-h --help help".split.includes?(ARGV.first)
  # === {{CMD}} -h|--help|help
  if ARGV[1]?
    DA.print_help ARGV[1]
  else
    DA.print_help
  end

when full_cmd == "generate release id"
  # === {{CMD}} generate release id
  puts DA_Deploy.generate_release_id

when full_cmd == "releases"
  # === {{CMD}} releases # Prints list of release in current working directory
  DA_Deploy.releases(Dir.current).each { |dir|
    puts dir
  }

when full_cmd == "latest"
  # === {{CMD}} latest release
  puts DA_Deploy.latest!(Dir.current)

when full_cmd == "init"
  # === {{CMD}} init
  DA_Deploy.init

when full_cmd == "init ssh"
  # === {{CMD}} init ssh
  DA_Deploy.init_ssh

when full_cmd == "init www"
  # === {{CMD}} init www
  DA_Deploy.init_www

when ARGV[0]? == "remove" && ARGV[1]?
  # === {{CMD}} remove service_name
  DA_Deploy.remove(ARGV[1])

when ARGV[0]? == "deploy" && ARGV[1]? && !ARGV[2]?
  # === {{CMD}} deploy service_name
  DA_Deploy.deploy(ARGV[1])

when "#{ARGV[0]?} #{ARGV[1]?}" == "deploy Public" && ARGV[2]?
  # === {{CMD}} deploy Public service_name
  DA_Deploy.deploy_public(ARGV[2])

when full_cmd["upload shell config to "]?
  # === {{CMD}} upload shell config
  DA_Deploy.upload_shell_config_to(ARGV.last)

when "service inspect" == "#{ARGV[0]?} #{ARGV[1]?}" && ARGV[2]?
  # === {{CMD}} service inspect dir_service
  service = DA_Deploy::Runit.new(ARGV[2])
  {% for x in "name service_link latest_linked? app_dir pids latest".split %}
    puts "{{x.id}}:  #{service.{{x.id}}.inspect}"
  {% end %}
  if service.latest?
    puts "sv_dir:  #{service.sv_dir}"
  end

when "service down" == "#{ARGV[0]?} #{ARGV[1]?}" && ARGV[2]?
  # === {{CMD}} service down dir_service
  DA_Deploy::Runit.new(ARGV[2]).down!

when "service up" == "#{ARGV[0]?} #{ARGV[1]?}" && ARGV[2]?
  # === {{CMD}} service up dir_service
  DA_Deploy::Runit.new(ARGV[2]).up!

when "inspect" == ARGV[0]? && ARGV[1]? && !ARGV[2]?
  # === {{CMD}} inspect app_name
  app = DA_Deploy::App.new(ARGV[1])
  puts "name:       #{app.name}"
  puts "dir:        #{app.dir}"
  puts "latest:     #{app.latest}"
  puts "releases:   #{app.releases.size}"
  puts "public dir: #{app.public_dir?}"
  puts "sv dir:     #{app.public_dir?}"

when "#{ARGV[0]?} #{ARGV[1]?} #{ARGV[2]?}" == "upload binary to"
  # === {{CMD}} upload binary to remote_name
  DA_Deploy.upload_binary_to_remote ARGV[3]

when "#{ARGV[0]?} #{ARGV[1]?} #{ARGV[2]?}" == "upload commit to"
  # === {{CMD}} upload commit to remote_name
  DA_Deploy.upload_commit_to_remote ARGV[3]

else
  DA.exit_with_error!(1, "!!! Invalid arguments: #{ARGV.map(&.inspect)}")

end # === case
