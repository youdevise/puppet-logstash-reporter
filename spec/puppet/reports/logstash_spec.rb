require 'spec_helper'

logstash = Puppet::Reports.report(:logstash)

module MockLogStashReport
  attr_reader :report_results_calls
  attr_reader :report_result
  def report_results(event)
    @report_result = event
    super(event)
    @report_results_calls = @report_results_calls||0 + 1
  end
  def time_now
      "Mon Mar 04 16:27:40 +0000 2013"
  end
end

describe logstash do
  def report_data
    JSON.parse(@processor.report_result)
  end

  before(:each) do
    @processor = Puppet::Transaction::Report.new("apply")
    @processor.extend(Puppet::Reports.report(:logstash))
    @processor.extend(MockLogStashReport)
  end
  it 'should be able to process' do
    @processor.process
    @processor.report_results_calls.should eql(1)
    exp = {
      "@fields" => {"report_format"=>3, "metrics"=>{}, "puppet_version"=>"3.1.0", "logs"=>[], "status"=>"failed", "end_time"=>"Mon Mar 04 16:27:40 +0000 2013", "environment"=>nil},
       "@source" => "puppet://ldn-dev-tdoran.youdevise.com",
       "@source_host" => "ldn-dev-tdoran.youdevise.com",
       "@source_path" => "/home/tdoran/code/git/puppet/modules/puppetmaster/spec/lib/../../lib/puppet/reports/logstash.rb",
       "@tags" => ["puppet-apply"]
    }
    report_data.should == exp
  end
end

