
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

when full_cmd == "generate id"
  # === {{CMD}} generate id
  puts DA_Deploy.generate_id

when full_cmd == "init"
  # === {{CMD}} init
  DA_Deploy.init

when "service inspect" == "#{ARGV[0]?} #{ARGV[1]?}" && ARGV[2]?
  # === {{CMD}} service inspect dir_service
  service = DA_Deploy::Runit.new(ARGV[2])
  puts service.dir
  puts service.state
  puts(service.pids.join("\n")) unless service.pids.empty?

when "service down" == "#{ARGV[0]?} #{ARGV[1]?}" && ARGV[2]?
  # === {{CMD}} service down dir_service
  DA_Deploy::Runit.new(ARGV[2]).down!

when "service up" == "#{ARGV[0]?} #{ARGV[1]?}" && ARGV[2]?
  # === {{CMD}} service up dir_service
  DA_Deploy::Runit.new(ARGV[2]).up!

when full_cmd == "watch"
  # === {{CMD}} watch
  DA_Deploy.watch

when "#{ARGV[0]?} #{ARGV[1]?}" == "upload to"
  # === {{CMD}} upload to remote_name
  DA_Deploy.upload_to_remote ARGV[2]

else
  DA.exit_with_error!(1, "!!! Invalid arguments: #{ARGV.map(&.inspect)}")

end # === case
