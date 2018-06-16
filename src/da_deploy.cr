

require "da"
require "file_utils"

module DA_Deploy

  DEPLOY_DIR  = "/deploy"
  SERVICE_DIR = "/var/service"

  extend self

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

end # === module DA_Deploy

require "./da_deploy/Init"
require "./da_deploy/Release"
require "./da_deploy/App"
require "./da_deploy/Linux"
require "./da_deploy/Dev"
require "./da_deploy/Deploy"
require "./da_deploy/Runit"
require "./da_deploy/Public_Dir"
require "./da_deploy/PG"
