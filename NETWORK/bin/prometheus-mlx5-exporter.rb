#!/usr/bin/env ruby

require 'optparse'
require 'stringio'
require 'webrick'
require 'zlib'

OPTS = {
  bind: '0.0.0.0',
  daemonize: false,
  log: '/dev/null',
  port: 9615,
  include_re: /./,  # Match every non-empty string
  exclude_re: /$^/  # Match no string
}

OP = OptionParser.new do |op|
  op.program_name = File.basename($0)

  op.banner = "Usage: #{op.program_name} [OPTIONS]"
  op.separator('')
  op.separator('Export Mellanox mlx5 sysfs Infiniband counters to Prometheus.')
  op.separator('Logging to stdout will force running in foreground, even with --daemonize.')
  op.separator('')
  op.separator 'Options:'
  op.on('-b', '--bind=IP', "Local IP address to bind to [#{OPTS[:bind]}]") do |o|
    OPTS[:bind] = o
  end
  op.on('-d', '--[no-]daemonize', "Run as daemon [#{OPTS[:daemonize]}]") do |o|
    OPTS[:daemonize] = o
  end
  op.on('-l', '--logfile=FILENAME', "File to log to ('-' for stdout) [none]") do |o|
    OPTS[:log] = o
  end
  op.on('-p', '--port=PORT', Integer, "Port to listen on [#{OPTS[:port]}]") do |o|
    OPTS[:port] = o
  end
  op.on('-i', '--include=REGEXP', Regexp, "Inclusion regexp [all]") do |o|
    OPTS[:include_re] = o
  end
  op.on('-x', '--exclude=REGEXP', Regexp, "Exclusion regexp [none]") do |o|
    OPTS[:exclude_re] = o
  end
  op.on_tail("-h", "--help", "Show this message") do
    puts op
    exit 1
  end
end
OP.parse!

if !ARGV.empty?
  puts OP
  exit 1
end

if OPTS[:log] == '-'
  OPTS[:log_io] = STDOUT
  OPTS[:daemonize] = false # Can't log to stdout and daemonize
else
  OPTS[:log_io] = File.open(OPTS[:log], 'a+')
  trap('HUP') {OPTS[:log_io].reopen(OPTS[:log], 'a+')}
end

OPTS[:log_io].sync = true

def run_server

  server = WEBrick::HTTPServer.new(
    BindAddress: OPTS[:bind],
    Port: OPTS[:port],
    AccessLog: [[OPTS[:log_io], WEBrick::AccessLog::CLF]],
    Logger: WEBrick::Log.new(OPTS[:log_io])
  )

  trap('INT')  {server.shutdown}
  trap('TERM') {server.shutdown}

  server.mount_proc '/' do |req, res|
    res.body = '<html><head><title>Prometheus mlx5 Exporter</title></head>'    +
               '<body><h1>Prometheus mlx5 Exporter</h1><p><a href="/metrics">' +
               'Metrics</a></p></body></html>'
    res.status = 200
  end

  server.mount_proc '/metrics' do |req, res|
    start = Time.now
    body = StringIO.new

    [[COUNTERS, 'counters'], [HW_COUNTERS, 'hw_counters']].each do |metrics, subdir|
      metrics.each do |metric, file, doc, type|
        type ||= 'counter'
        metric = "mlx5_#{metric}"
        metric += '_total' if type == 'counter'

        first = true
        Dir.glob("#{GLOB}#{subdir}/#{file}") do |fname|
          # This sets up the capture backreferences for device and port
          next unless fname =~ RE
          device, port = $1, $2

          # Make sure we can convert value to Float
          value = Float(File.open(fname) {|f| f.gets.chomp}) rescue nil
          next if value.nil?

          if first
            first = false
            body.puts "# HELP #{metric} #{doc}"
            body.puts "# TYPE #{metric} #{type}"
          end
          body.puts "#{metric}{device=\"#{$1}\",port=\"#{$2}\"} #{value}"
        end # Dir.glob
      end # metrics.each
    end # [[]].each

    body.puts "# HELP mlx5_scrape_duration_seconds Number of seconds to scrape the mlx5 exporter"
    body.puts "# TYPE mlx5_scrape_duration_seconds gauge"
    body.puts "mlx5_scrape_duration_seconds #{(Time.now-start).to_f}"

#    if req.accept_encoding.index('gzip')
#      res['Content-Encoding'] = 'gzip'
#      res.body = Zlib.gzip(body.string)
#    else
      res.body = body.string
#    end
    res.status = 200
  end

  begin
    WEBrick::Daemon.start if OPTS[:daemonize]
    server.start
  ensure
    server.shutdown
  end
end

# Metric name
# File name
# Docstring
# [type]

GLOB = '/sys/class/infiniband/*/ports/*/'
RE   = %r{^/sys/class/infiniband/([^/]+)/ports/([^/]+)/}

COUNTERS = 
[
	[
		"port_rcv_data",
		"port_rcv_data",
		"Total number of data octets, divided by 4 (lanes), received on all VLs."
	],
	[
		"port_rcv_packets",
		"port_rcv_packets",
		"Total number of packets (this may include packets containing Errors."
	],
	[
		"port_multicast_rcv_packets",
		"port_multicast_rcv_packets",
		"Total number of multicast packets, including multicast packets containing errors."
	],
	[
		"port_unicast_rcv_packets",
		"port_unicast_rcv_packets",
		"Total number of unicast packets, including unicast packets containing errors."
	],
	[
		"port_xmit_data",
		"port_xmit_data",
		"Total number of data octets, divided by 4 (lanes), transmitted on all VLs."
	],
	[
		"port_xmit_packets",
		"port_xmit_packets_64",
		"Total number of packets transmitted on all VLs from this port."
	],
	[
		"port_rcv_switch_relay_errors",
		"port_rcv_switch_relay_errors",
		"Total number of packets received on the port that were discarded because they could not be forwarded by the switch relay."
	],
	[
		"port_rcv_errors",
		"port_rcv_errors",
		"Total number of packets containing an error that were received on the port."
	],
	[
		"port_rcv_constraint_errors",
		"port_rcv_constraint_errors",
		"Total number of packets received on the switch physical port that are discarded."
	],
	[
		"local_link_integrity_errors",
		"local_link_integrity_errors",
		"The number of times that the count of local physical errors exceeded the threshold specified by LocalPhyErrors."
	],
	[
		"port_xmit_wait",
		"port_xmit_wait",
		"The number of ticks during which the port had data to transmit but no data was sent during the entire tick."
	],
	[
		"port_multicast_xmit_packets",
		"port_multicast_xmit_packets",
		"Total number of multicast packets transmitted on all VLs from the port. This may include multicast packets with errors."
	],
	[
		"port_unicast_xmit_packets",
		"port_unicast_xmit_packets",
		"Total number of unicast packets transmitted on all VLs from the port. This may include unicast packets with errors."
	],
	[
		"port_xmit_discards",
		"port_xmit_discards",
		"Total number of outbound packets discarded by the port because the port is down or congested."
	],
	[
		"port_xmit_constraint_errors",
		"port_xmit_constraint_errors",
		"Total number of packets not transmitted from the switch physical port."
	],
	[
		"port_rcv_remote_physical_errors",
		"port_rcv_remote_physical_errors",
		"Total number of packets marked with the EBP delimiter received on the port."
	],
	[
		"symbol_error",
		"symbol_error",
		"Total number of minor link errors detected on one or more physical lanes."
	],
	[
		"vL15_dropped",
		"VL15_dropped",
		"Number of incoming VL15 packets dropped due to resource limitations (e.g., lack of buffers) of the port."
	],
	[
		"link_error_recovery",
		"link_error_recovery",
		"Total number of times the Port Training state machine has successfully completed the link error recovery process."
	],
	[
		"link_downed",
		"link_downed",
		"Total number of times the Port Training state machine has failed the link error recovery process and downed the link."
	],
]

HW_COUNTERS =
[
	[
		"duplicate_request",
		"duplicate_request",
		"Number of duplicate request packets."
	],
	[
		"implied_nak_seq_err",
		"implied_nak_seq_err",
		"Number of time the requested decided an ACK with a PSN larger than the expected PSN for an RDMA read or response."
	],
	[
		"lifespan",
		"lifespan",
		"The maximum period in ms which defines the aging of the counter reads. Two consecutive reads within this period might return the same values",
    "gauge"
	],
	[
		"local_ack_timeout_err",
		"local_ack_timeout_err",
		"The number of times QP's ack timer expired for RC, XRC, DCT QPs at the sender side."
	],
	[
		"np_cnp_sent",
		"np_cnp_sent",
		"The number of CNP packets sent by the Notification Point when it noticed congestion experienced in the RoCEv2 IP header (ECN bits)."
	],
	[
		"np_ecn_marked_roce_packets",
		"np_ecn_marked_roce_packets",
		"The number of RoCEv2 packets received by the notification point which were marked for experiencing the congestion (ECN bits where '11' on the ingress RoCE traffic) ."
	],
	[
		"out_of_buffer",
		"out_of_buffer",
		"The number of drops occurred due to lack of WQE for the associated QPs."
	],
	[
		"out_of_sequence",
		"out_of_sequence",
		"The number of out of sequence packets received."
	],
	[
		"packet_seq_err",
		"packet_seq_err",
		"The number of received NAK sequence error packets. The QP retry limit was not exceeded."
	],
	[
		"req_cqe_error",
		"req_cqe_error",
		"The number of times requester detected CQEs completed with errors."
	],
	[
		"req_cqe_flush_error",
		"req_cqe_flush_error",
		"The number of times requester detected CQEs completed with flushed errors."
	],
	[
		"req_remote_access_errors",
		"req_remote_access_errors",
		"The number of times requester detected remote access errors."
	],
	[
		"req_remote_invalid_request",
		"req_remote_invalid_request",
		"The number of times requester detected remote invalid request errors."
	],
	[
		"resp_cqe_error",
		"resp_cqe_error",
		"The number of times responder detected CQEs completed with errors."
	],
	[
		"resp_cqe_flush_error",
		"resp_cqe_flush_error",
		"The number of times responder detected CQEs completed with flushed errors."
	],
	[
		"resp_local_length_error",
		"resp_local_length_error",
		"The number of times responder detected local length errors."
	],
	[
		"resp_remote_access_errors",
		"resp_remote_access_errors",
		"The number of times responder detected remote access errors."
	],
	[
		"rnr_nak_retry_err",
		"rnr_nak_retry_err",
		"The number of received RNR NAK packets. The QP retry limit was not exceeded."
	],
	[
		"rp_cnp_handled",
		"rp_cnp_handled",
		"The number of CNP packets handled by the Reaction Point HCA to throttle the transmission rate."
	],
	[
		"rp_cnp_ignored",
		"rp_cnp_ignored",
		"The number of CNP packets received and ignored by the Reaction Point HCA."
	],
	[
		"rx_atomic_requests",
		"rx_atomic_requests",
		"The number of received ATOMIC request for the associated QPs."
	],
	[
		"rx_dct_connect",
		"rx_dct_connect",
		"The number of received connection request for the associated DCTs."
	],
	[
		"rx_read_requests",
		"rx_read_requests",
		"The number of received READ requests for the associated QPs."
	],
	[
		"rx_write_requests",
		"rx_write_requests",
		"The number of received WRITE requests for the associated QPs."
	],
	[
		"rx_icrc_encapsulated",
		"rx_icrc_encapsulated",
		"The number of RoCE packets with ICRC errors."
	]
]

# Pre-filter counters and hw_counters with include/exclude regexps
COUNTERS.select! {|a| a[0] =~ OPTS[:include_re]}
COUNTERS.reject! {|a| a[0] =~ OPTS[:exclude_re]}
HW_COUNTERS.select! {|a| a[0] =~ OPTS[:include_re]}
HW_COUNTERS.reject! {|a| a[0] =~ OPTS[:exclude_re]}

# Run the server!
run_server
