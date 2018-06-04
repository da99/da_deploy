
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

when full_cmd == "watch"
  # === {{CMD}} watch
  DA_Deploy.watch

when "#{ARGV[0]?} #{ARGV[1]?}" == "upload to"
  # === {{CMD}} upload to remote_name
  DA_Deploy.upload_to_remote ARGV[2]

else
  DA.exit_with_error!(1, "!!! Invalid arguments: #{ARGV.map(&.inspect)}")

end # === case
