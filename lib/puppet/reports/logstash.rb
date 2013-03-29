require 'rubygems'
require 'puppet'
require 'socket'
require 'timeout'
require 'json'
require 'zmq'

unless Puppet.version >= '2.6.5'
  fail "This report processor requires Puppet version 2.6.5 or later"
end

Puppet::Reports.register_report(:logstash) do

  desc <<-DESCRIPTION
  Reports status of Puppet Runs to a Logstash TCP input
DESCRIPTION

  @@clock = Time

  @@ctx = ZMQ::Context.new
  @@publisher = @@ctx.socket ZMQ::PUB
  @@publisher.setsockopt(ZMQ::LINGER, 0)
  @@publisher.setsockopt(ZMQ::HWM, 10)
  @@publisher.connect "tcp://127.0.0.1:5222"

  def process
    msgs = []
    self.logs.each do |log|
      msgs << log.message
    end

    event = Hash.new
    event["@source"] = "puppet://#{self.host}"
    event["@source_path"] = __FILE__
    #event["@source"] = "puppet://#{self.host}/#{log.source}"
    #event["@source_path"] = "#{log.file}" || __FILE__
    event["@source_host"] = self.host
    event["@tags"] = ["puppet-#{self.kind}"]
    #event["@tags"] << log.tags if log.tags
    event["@fields"] = Hash.new
    event["@fields"]["environment"] = self.environment
    event["@fields"]["report_format"] = self.report_format
    event["@fields"]["puppet_version"] = self.puppet_version
    event["@fields"]["status"] = self.status
    #event["@fields"]["start_time"] = log.time
    event["@fields"]["end_time"] = time_now
    event["@fields"]["metrics"] = {}
    metrics.each do |k,v|
      event["@fields"]["metrics"][k] = {}
      v.values.each do |val|
        event["@fields"]["metrics"][k][val[1]] = val[2]
      end
    #  event["@fields"]["metrics"][k] = v.values
    #  event["@fields"]["metrics"][k] = {
    #    v.name => v.values
    #  }
    end
    event["@fields"]["logs"] = msgs
    event["@message"] = "puppet run on #{self.host}"

    begin
      report_results JSON.pretty_generate(event)
    rescue Exception => e
      Puppet.err "Failed to write to logstash: #{e.message}"
    end
  end
  def report_results(event)
    File.open('/tmp/puppet_run.json', 'w') {|f| f.write(event) }
    @@publisher.send(event)
  end
  def time_now
    Time.now
  end
end

